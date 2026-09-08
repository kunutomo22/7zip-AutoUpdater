#エラー挙動定義
$ErrorActionPreference = "Stop" #エラーが発生した場合にスクリプトを停止する

#定数定義
$RELEASE_HISTORY_URL = "https://www.7-zip.org/history.txt" #7zipのリリース履歴URL
$RELEASE_DESCRIPTION_SEPARATOR_BAR = "-------------------------" #7zipのリリース履歴中にあるタイトル&リリース日付とリリース内容を分ける区切り行内容
$OUT_FILE_BASE_NAME = "7zip-ReleaseList" #出力ファイルのベース名

#エラースタッククリア
$Error.Clear()

#変数初期設定
$MyPath = $MyInvocation.MyCommand.Path #スクリプトのパス
$MyBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MyPath) #スクリプトのベース名
$MyParentPath = Split-Path -Parent $MyInvocation.MyCommand.Path #スクリプトの親ディレクトリパス
$MyOutputFolderPath = Join-Path -Path $MyParentPath -ChildPath "Output" #出力フォルダパス
$MyLogFolderPath = Join-Path -Path $MyParentPath -ChildPath "Log" #ログフォルダパス
$MyLogFilePath = Join-Path -Path $MyLogFolderPath -ChildPath ($MyBaseName + ".log") #ログファイルパス
$MyCommonFolderPath = Join-Path -Path $MyParentPath -ChildPath "Common" #共通関数フォルダパス
$MyCommonFilePath = Join-Path -Path $MyCommonFolderPath -ChildPath "Common.ps1" #共通関数ファイルパス
.$MyCommonFilePath #共通関数読み込み
$MySettingFilePath = Join-Path -Path $MyParentPath -ChildPath "Setting.txt" #設定ファイルパス

#アセンブリ読み込み
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try{
	#ログ出力関数
	function Logger{
		param(
			[string]$Title,
			[ValidateSet(
				"None",
				"Error",
				"Question",
				"Warning",
				"Information"
			)][string]$Level = "Information",
			[string]$Message,
			[string]$LogLevel,
			[bool]$Popup
		)
		if(!$Popup -and ($Level -ne "Question")){
			$Title = ""
		}
		$OutputLevelArray = @()
		switch ($LogLevel){
			"Error"       { $OutputLevelArray = @("Error","Question") }
			"Warning"     { $OutputLevelArray = @("Warning","Error","Question") }
			"Information" { $OutputLevelArray = @("Information","Warning","Error","Question") }
			"None"        { $OutputLevelArray = @("None","Information","Warning","Error","Question") }
		}
		if($Level -in $OutputLevelArray){
			return LoggerEX -Title $Title -Level $Level -Message $Message
		}
	}
	
	#リリース履歴リストオブジェクト作成
	function ReleaseListObjectReturn{
		param(
			$RequestContent
		)
        $Lines = $RequestContent.Split("`n")
		$DescriptionFlag = $false
        $ReleaseList = New-Object -TypeName System.Collections.ArrayList
		for($LineIndex = 0;$LineIndex -lt $Lines.length;$LineIndex++){
            $Line = $Lines[$LineIndex]
			if($Line.Trim() -eq $RELEASE_DESCRIPTION_SEPARATOR_BAR){
				$ReleaseNameAndDate = $Lines[$LineIndex - 1].Trim()
                $SpaceCount = 0
                $Version = ""
                $ReleaseType = ""
                $ReleaseTypeVersion = ""
                $TemplateString = ""
                for($Index = 0;$Index -lt $ReleaseNameAndDate.length;$Index++){
                    if($SpaceCount -le 3){
                        if($ReleaseNameAndDate[$Index] -eq " "){
                            $SpaceCount ++
                            switch($SpaceCount){
                                1{$Version = $TemplateString}
                                2{$ReleaseType = $TemplateString}
                                3{$ReleaseTypeVersion = $TemplateString}
                            }
                            $TemplateString = ""
                            continue
                        }
                    }
                    if($ReleaseNameAndDate[$Index] -eq "-"){
                        $ReleaseDate = $ReleaseNameAndDate[($Index-4)..($ReleaseNameAndDate.length-1)] -join ""
                        $ReleaseNameAndDate = ""
                        break
                    }
                    $TemplateString += $ReleaseNameAndDate[$Index]
                }
				$DescriptionFlag = !$DescriptionFlag
				$DescriptionLines = @()
                continue
			}
			if($DescriptionFlag){
				if($Line -eq "`r" -and ($DescriptionLines.Count -ne 0)){
					$Descriptionflag = !$Descriptionflag
                    $ReleaseObject = New-Object -TypeName PSCustomObject -Property @{Version = $Version;ReleaseType = $ReleaseType;ReleaseTypeVersion = $ReleaseTypeVersion;ReleaseDate = $ReleaseDate;Description = (($DescriptionLines -join "`n") + "`n")}
					$ReleaseList.Add($ReleaseObject) | Out-Null
                    continue
				}
				$DescriptionLines += $Line.replace("`r","  `r")
			}
		}
        return $ReleaseList
	}

	function Export-Markdown{
		param(
			$InputObject,
			[string]$FilePath,
			[string]$Encoding
		)
		$MarkdownString = @()
		$MarkdownString += ("# " + $PageTitle)
		foreach($Object in $InputObject){
			$MarkdownString += ("## " + $Object.Version + " " + $Object.ReleaseType + " " + $Object.ReleaseTypeVersion + " - " + $Object.ReleaseDate)
			$MarkdownString += $Object.Description
			$MarkdownString += ""
		}
		$MarkdownString | Out-File -FilePath $FilePath -Encoding $Encoding | Out-Null
	}

	#出力ファイル作成
	function FileOutputer{
		param(
			$Object,
			[string]$OutPath,
			[string]$Encoding,
			[string]$CSS
		)
		if(!([System.IO.Path]::GetExtension($OutPath) -in ".csv",".json",".xml",".html",".md")){
			Logger -Title "無効なファイル拡張子" -Level "Warning" -Message ("指定された"+[System.IO.Path]::GetExtension($OutPath)+"ファイル拡張子はサポートされていません。") -LogLevel $LogLevel -Popup $popup
			if("yes" -eq (Logger -Title "無効なファイル拡張子" -Level "Question" -Message "続行しますか？" -LogLevel $LogLevel -Popup $popup)){
				Logger -Title "無効なファイル拡張子" -Level "Warning" -Message "出力内容のみCSVファイルの内容になります。" -LogLevel $LogLevel -Popup $true
			}else{
				throw "無効なファイル拡張子が設定ファイルで指定されたため、処理を中止します。"
			}
		}
        Logger -Message "ファイルに出力しています"
		switch([System.IO.Path]::GetExtension($OutPath)){
			".json"{$Object | ConvertTo-Json | Out-File -FilePath $OutPath -Encoding $Encoding}
			".xml"{$Object | Export-Clixml -Path $OutPath -Encoding $Encoding}
			".html"{$Object | ConvertTo-Html -Head $CSS -Title $PageTitle | Out-File -FilePath $OutPath -Encoding $Encoding}
			".md"{Export-Markdown -InputObject $Object -FilePath $OutPath -Encoding $Encoding}
            default {$Object | Export-Csv -Path $OutPath -Encoding $Encoding -NoTypeInformation}
		}
        Logger -Message ($OutPath + "に出力しました")
	}

	#メイン
	Start-Transcript -Path $MyLogFilePath
	Write-Host "7zip-ReleaseListingToolを開始します。" -ForegroundColor Green
	Write-Host "設定ファイルを読み込みます。"
	Invoke-Expression -Command (cat -Path $MySettingFilePath -Raw)
	Write-Host "設定ファイルを読み込みました。"
	
	Logger -Title "設定ファイル読み込み結果" -Level "None" -Message ("[" + ((cat $MySettingFilePath -Encoding UTF8 | ForEach-Object {if(($_)[0] -eq "`$"){$_ | cfs -Delimiter "#"}} | ForEach-Object {$_.P1.Trim()}) -join ",") + "]") -LogLevel $LogLevel -Popup $Popup
	
	$OutputFilePath = Join-Path -Path $MyOutputFolderPath -ChildPath ($OUT_FILE_BASE_NAME + "." + $FileExtension)#出力ファイルパス決定
    Logger -Level "None" -Message ("出力ファイルパス[" + $OutputFilePath + "]")

	Logger -Level "Information" -Message "7zipのリリース履歴取得実行" -LogLevel $LogLevel -Popup $Popup
	if(($OutType -eq "File") -and ($FileExtension -eq "txt")){
		Check-WebRequest -URL $RELEASE_HISTORY_URL
		Simple-WebRequest -URL $RELEASE_HISTORY_URL -OutputPath $OutputFilePath | Out-Null
		Logger -Level "Information" -Message ("7zipのリリース履歴を[" + $OutputFilePath + "]に出力しました。") -LogLevel $LogLevel -Popup $Popup
		return
	}else{
		$RequestObject = Simple-WebRequest -URL $RELEASE_HISTORY_URL
        $script:PageTitle = $RequestObject.Content.Split("`r`n")[0]
        Logger -Level "None" -Message ("出力ファイルタイトル[" + $PageTitle + "]")
	}
	if($OutType -eq "Console"){
		echo $RequestObject.Content
		read-host "Enterを押してください"
		return
	}
	$ReleaseListObject = ReleaseListObjectReturn -RequestContent $RequestObject.Content
	Switch($OutType){
		"Popup"{TablePopup -Title $PageTitle -ObjectArray $ReleaseListObject -ViewNotePropertyArray @("ReleaseDate","Version","ReleaseType","ReleaseTypeVersion","Description") -SizeXY @($PopupSizeX,$PopupSizeY)}
		"File"{FileOutputer -Object $ReleaseListObject -OutPath $OutputFilePath -CSS $css -Encoding $Encoding}
	}
}catch{
	Logger -Title "7zip-ReleaseListingToolの実行中にエラーが発生しました。" -Level "Error" -Message $Error[0].Exception.Message -LogLevel $LogLevel -Popup $true
}finally{
	Stop-Transcript
	Write-Host "7zip-ReleaseListingToolを終了します。" -ForegroundColor Green
}
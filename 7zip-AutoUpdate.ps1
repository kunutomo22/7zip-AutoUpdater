#エラー挙動定義
$ErrorActionPreference = "Stop" #エラーが発生した場合にスクリプトを停止する

#定数定義
$RELEASE_API_URL = "https://api.github.com/repos/ip7z/7zip/releases" #GitHub APIのURL

#エラースタッククリア
$Error.Clear()

#変数初期設定
$MyPath = $MyInvocation.MyCommand.Path #スクリプトのパス
$MyBaseName = [System.IO.Path]::GetFileNameWithoutExtension($MyPath) #スクリプトのベース名
$MyParentPath = Split-Path -Parent $MyInvocation.MyCommand.Path #スクリプトの親ディレクトリパス
$MyOutputFolderPath = Join-Path -Path $MyParentPath -ChildPath "Output" #出力フォルダパス
$MyLogFilePath = Join-Path -Path $MyOutputFolderPath -ChildPath ($MyBaseName + ".log") #ログファイルパス
$MyCommonFolderPath = Join-Path -Path $MyParentPath -ChildPath "Common" #共通関数フォルダパス
$MySubshellFolderPath = Join-Path -Path $MyParentPath -ChildPath "Subshell" #サブシェルフォルダパス
$MySubshellOutputFolderPath = Join-Path -Path $MySubshellFolderPath -ChildPath "Output" #サブシェル出力フォルダパス
$MySubshellOutputFilePath = Join-Path -Path $MySubshellOutputFolderPath -ChildPath "7zip-ReleaseList.csv" #サブシェル出力ファイルパス
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

	function SubshellExecute{
		param(
			[string]$ShellNickName,
			[string]$ShellFileName
		)
		$ShellFilePath = Join-Path -Path $MySubshellFolderPath -ChildPath $ShellFileName
		$SubshellProcess = Start -FilePath "powershell" -ArgumentList $ShellFilePath -PassThru -Wait -NoNewWindow
		if($SubshellProcess.ExitCode -ne 0){
			Logger -Level "Error" -Message ($ShellNickName + "のサブシェルの実行に失敗しました。終了コード：" + $SubshellProcess.ExitCode) -LogLevel $LogLevel -Popup $Popup
		}
	}

	#メイン
	Start-Transcript -Path $MyLogFilePath
	Write-Host "7zip-AutoUpdaterを開始します。" -ForegroundColor Green
	Write-Host "設定ファイルを読み込みます。"
	Invoke-Expression -Command (cat -Path $MySettingFilePath -Raw)
	Write-Host "設定ファイルを読み込みました。"
	
	Logger -Title "設定ファイル読み込み結果" -Level "None" -Message ("[" + ((cat $MySettingFilePath -Encoding UTF8 | ForEach-Object {if(($_)[0] -eq "`$"){$_ | cfs -Delimiter "#"}} | ForEach-Object {$_.P1.Trim()}) -join ",") + "]") -LogLevel $LogLevel -Popup $Popup
	
	Logger -Level "None" -Message ("GitHub Release API実行 URL：" + $RELEASE_API_URL) -LogLevel $LogLevel -Popup $Popup
	$WebRequestReturnObject = Simple-WebRequest -URL $RELEASE_API_URL
	if($WebRequestReturnObject.StatusCode -ne 200){
		$Message = "GitHub Release APIへのアクセスに失敗しました。ステータスコード：" + $WebRequestReturnObject.StatusCode
		Logger -Level "Error" -Message $Message -LogLevel $LogLevel -Popup $Popup
		throw $Message
	}
	Logger -Level "None" -Message "GitHub Release API実行完了" -LogLevel $LogLevel -Popup $Popup
	$WebRequestReturnContentObject = $WebRequestReturnObject.Content | ConvertFrom-Json
	Logger -Level "None" -Message ("サブシェル実行 FileName：7zip-ReleaseList.ps1") -LogLevel $LogLevel -Popup $Popup
	SubshellExecute -ShellNickName "7zip-ReleaseListingTool" -ShellFileName "7zip-ReleaseList.ps1"
	Logger -Level "None" -Message ("サブシェル実行完了 FileName：7zip-ReleaseList.ps1") -LogLevel $LogLevel -Popup $Popup
	$LastVersion = (Import-Csv -Path $MySubshellOutputFilePath | where -FilterScript {($_.ReleaseTypeVersion -eq "") -and ($_.ReleaseType -eq "")} | sort -Property ReleaseDate -Descending)[0].Version
	$ExeAssetObject = $WebRequestReturnContentObject | where -FilterScript {($_.tag_name -eq $LastVersion)} | select -ExpandProperty assets | where -FilterScript {($_.name -like "7z*-x64.exe")}
	$InstallerPath = Join-Path -Path $MyOutputFolderPath -ChildPath $ExeAssetObject.name
	Logger -Level "Information" -Message "インストーラ―ダウンロード"
	Logger -Level "None" -Message ("インストーラーのダウンロード先パス：" + $InstallerPath) -LogLevel $LogLevel -Popup $Popup
	Logger -Level "None" -Message ("インストーラーのダウンロード URL：" + $ExeAssetObject.browser_download_url) -LogLevel $LogLevel -Popup $Popup
	Simple-WebRequest -URL $ExeAssetObject.browser_download_url -OutputPath $InstallerPath | Out-Null
	Logger -Level "Information" -Message "インストーラ―ダウンロード完了"
	Logger -Level "Information" -Message "インストーラ―の実行"
	$InstallerProcess = Start -FilePath $InstallerPath -ArgumentList ("/S /D=`"" + $InstallPath + "`"") -PassThru -Wait -NoNewWindow
	if($InstallerProcess.ExitCode -ne 0){
		Logger -Level "Error" -Message ("インストーラーの実行に失敗しました。終了コード：" + $InstallerProcess.ExitCode) -LogLevel $LogLevel -Popup $Popup
		throw ("インストーラーの実行に失敗しました。終了コード：" + $InstallerProcess.ExitCode)
	}
	Logger -Level "Information" -Message "インストーラ―の実行完了"
	if($InstallerRemove){
		Logger -Level "Information" -Message "インストーラ―の削除"
		Remove-Item -Path $InstallerPath -Force
		Logger -Level "Information" -Message "インストーラ―の削除完了"
	}
}catch{
	Logger -Title "7zip-AutoUpdater" -Level "Error" -Message $Error[0].Exception.Message -LogLevel $LogLevel -Popup $true
}finally{
	Stop-Transcript
	Write-Host "7zip-AutoUpdaterを終了します。" -ForegroundColor Green
}
function LoggerEX {
	param(
		[string]$Title,
		[ValidateSet(
            "None",
            "Error",
            "Question",
            "Warning",
            "Information"
		)][string]$Level = "Information",
		[string]$Message
	)
	if($Title -ne ""){
		if($Level -eq "Question"){
			Write-Host(LoggerEX -Message ("ポップアップでユーザに" + $Title + "を質問しています"))
			$Result = YesNoPopup -Title $Title -Level $Level -Message $Message
			$Message = "ユーザは" + $Title + "に" + $Result + "と回答しました"
            Write-Host(LoggerEX -Message $Message)
            return $Result
		}else{
			OKPopup -Title $Title -Level $Level -Message $Message
		}
	}
	return (("[" + (Get-Date -Format "yyyy/MM/dd HH:mm:ss") + "] " + "[" + ((" " * [math]::Floor((11 - $Level.Length)/2)) + $Level).PadRight(11)) + "] " + $Message)
}

function OKPopup{
	param(
		[string]$Title,
		[string]$Level,
		[string]$Message
	)
	[System.Windows.Forms.MessageBox]::Show($Message, $Title, "OK",$Level) | Out-Null
}

function YesNoPopup{
	param(
		[string]$Title,
		[string]$Level,
		[string]$Message
	)
	return [System.Windows.Forms.MessageBox]::Show($Message, $Title, "YesNo",$Level)
}

function Simple-WebRequest{
	param(
		[string]$URL,
		[string]$OutputPath
	)
	if($URL -and $OutputPath){
		Check-WebRequest -URL $URL
		Invoke-webRequest -UseBasicParsing -Uri $URL -OutFile $OutputPath | Out-Null
		return $OutputPath
	}else{
		return (Invoke-webRequest -UseBasicParsing -Uri $URL)
	}
}

function Check-WebRequest{
	param(
		[string]$URL
	)
	$StatusCode = (Invoke-webRequest -UseBasicParsing -Uri $URL).StatusCode
	if( $StatusCode -ne 200){
		throw ("URLにアクセスできませんでした。URL:" + $URL + "StatusCode:" + $StatusCode)
	}
}

function TablePopup{
    param(
        [string]$Title,
        [string]$Position="CenterScreen",
        [int[]]$SizeXY = @(750,800),
        $ObjectArray,
        [string[]]$ViewNotePropertyArray
    )

    # フォーム
    $Form = New-Object System.Windows.Forms.Form
    $Form.Size = New-Object System.Drawing.Size($SizeXY[0], $SizeXY[1])
    $Form.StartPosition = [System.Windows.Forms.FormStartPosition]::$Position
    $Form.Text = $Title

    # 一度レイアウトを確定させる
    $Form.Show()
    $Form.Hide()

    # クライアント領域のサイズを取得
    $ClientWidth  = $Form.ClientSize.Width
    $ClientHeight = $Form.ClientSize.Height

    # 各GUI要素の間隔
    $SPACE = 10
    $BUTTON_SIZE = @(80,30)

    # リストビュー
    $View = New-Object System.Windows.Forms.ListView
    $View.Location = New-Object System.Drawing.Point($SPACE, $SPACE)
    $ViewSizeX = $ClientWidth  - 2 * $SPACE
    $ViewSizeY = $ClientHeight - 3 * $SPACE - $BUTTON_SIZE[1]
    $View.Size = New-Object System.Drawing.Size($ViewSizeX, $ViewSizeY)
    $View.View = "Details"
    $View.GridLines = $True

    foreach($Property in $ViewNotePropertyArray){
        [void]$View.Columns.Add($Property)
    }

    foreach($ObjectItem in $ObjectArray){
        foreach($Property in $ViewNotePropertyArray){
            if($ViewNotePropertyArray.IndexOf($Property) -eq 0){
                $Item = New-Object System.Windows.Forms.ListViewItem($ObjectItem.$Property)
            }else{
                [void]$Item.SubItems.Add($ObjectItem.$Property)
            }
        }
        [void]$View.Items.Add($Item)
    }

    $View.AutoResizeColumns([System.Windows.Forms.ColumnHeaderAutoResizeStyle]::ColumnContent)

    # ボタン
    $Button = New-Object System.Windows.Forms.Button
    $ButtonLocationX = $ClientWidth  - $BUTTON_SIZE[0] - $SPACE
    $ButtonLocationY = $ClientHeight - $BUTTON_SIZE[1] - $SPACE
    $Button.Location = New-Object System.Drawing.Point($ButtonLocationX, $ButtonLocationY)
    $Button.Size = New-Object System.Drawing.Size($BUTTON_SIZE[0], $BUTTON_SIZE[1])
    $Button.Text = "Close"
    $Button.FlatStyle = "popup"
    $Button.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    $Form.Controls.AddRange(@($View,$Button))
    $Form.ShowDialog() | Out-Null
}
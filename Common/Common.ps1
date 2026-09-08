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

### VideoDL

# Import ShowUI
try
{
	Import-Module ShowUI -ErrorAction Stop
}
catch
{
	Write-Warning "ShowUI module wasn't found."
	Write-Host "VideoDL requires PowerShell v3 (or newer) and the ShowUI module to run."
	Write-Host "`nTo install the ShowUI module, open a console and use the Install-Module cmdlet:"
	Write-Host "Install-Module -Name ShowUI"
	Write-Host "`nIf the Install-Module cmdlet isn't available in your PowerShell version, you can"
	Write-Host "download ShowUI from http://show-ui.com (Go to 'Download' -> 'Download Latest')."
	Write-Host "Do you want to open http://show-ui.com in your default browser now? (y/n) " -NoNewline
	$answer = Read-Host
	if ($answer -eq "y") {Start http://show-ui.com/}
	Read-Host "`nPress Enter to exit"
	exit
}

# Import PresentationCore. This is needed to get the text from the clipboard.
Add-Type -Assembly PresentationCore


# Test if run with the -file parameter.
function test_function {$null}

try
{
	Global:test_function
}
catch
{
	Write-Warning "VideoDL not loaded correctly."
	Write-Host "`nVideoDL must be run with the -file parameter."
	Write-Host "`nTo run VideoDL from the console try:"
	Write-Host "> powershell -file 'videodl.ps1'"
	Write-Host "`nRefer to the Readme for more information."
	Read-Host "`nPress Enter to exit"
	exit
}


# URL path
if (!$(Test-Path .\urls.txt -PathType Leaf)) {New-Item -ItemType File -Name "urls.txt" | Out-Null}
$urlpath = Resolve-Path .\urls.txt -ErrorAction SilentlyContinue

# Read ini file.
$inipath = ".\videodl.ini"
$ini = [ordered]@{}

switch -regex -file $inipath
{
	"(^[^#;].+?)\s*=\s*(.*)"
    {
        $ini[$matches[1]]=$matches[2]
    }
}


# Show / hide console window.

Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);'

function ShowConsole
{
	$consolePtr = [Console.Window]::GetConsoleWindow()
	[Console.Window]::ShowWindow($consolePtr, 4)
	$script:ShowHideCheck = 1
}

function HideConsole
{
	$consolePtr = [Console.Window]::GetConsoleWindow()
	[Console.Window]::ShowWindow($consolePtr, 0)
	$script:ShowHideCheck = 0
}

if ($ini.HideConsole -eq "True") {HideConsole; cls}

function ShowHideConsole
{
	if ($ShowHideCheck -eq 0)
	{
		ShowConsole
	}
	else
	{
		HideConsole
	}
}


# Define gradient background colors.
$ButtonBackColor = New-LinearGradientBrush -StartPoint "0, 0" -EndPoint "0, 1" $(
	New-GradientStop -Color '#FFF0F0F0' -Offset 0
	New-GradientStop -Color '#FFE5E5E5' -Offset 1
)


# Check for Youtube-dl and FFmpeg.
function CheckYoutubedl
{
	if (($ini.YoutubedlPath -like "*youtube-dl.exe") -and ((Resolve-Path -literalPath $ini.YoutubedlPath -ErrorAction SilentlyContinue).Path))
	{
		$ytdl = $(Get-Command $ini.YoutubedlPath)
		$script:ytdlPath = $ytdl.Path

		if ($ini.DisplayYoutubedlMessage -eq "True")
		{
			write-output "Found youtube-dl.exe."
			write-output "Path    : $ytdlPath"
			write-output "Version : $($ytdl.FileVersionInfo.FileVersion)`n"
		}
	}
	elseif (Get-Command youtube-dl.exe -ErrorAction SilentlyContinue)
	{
		$ytdl = $(Get-Command youtube-dl.exe)
		$script:ytdlPath = $ytdl.Path

		if ($ini.DisplayYoutubedlMessage -eq "True")
		{
			write-output "Found youtube-dl.exe."
			write-output "Path    : $ytdlPath"
			write-output "Version : $($ytdl.FileVersionInfo.FileVersion)`n"
		}
	}
	else
	{
		write-warning "youtube-dl.exe was not found."
	}
}

function Checkffmpeg
{
	if (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue)
	{
		if ($ini.DisplayFFmpegMessage -eq "True")
		{
			write-output "Found ffmpeg.exe."
			write-output "Path    : $((Get-Command ffmpeg.exe).Path)`n"
		}
	}
	elseif ($ini.DisplayFFmpegWarning -eq "True")
	{
		write-warning "ffmpeg.exe was not found."
	}
}

CheckYoutubedl
Checkffmpeg


# Create the FavoriteChannels, OutputCustom and FormatCustom arrays.

$FavoriteChannels =  @(($ini.GetEnumerator() | where key -like "FavoriteChannel*" | where value -notlike "").value)
$OutputCustom =  @($ini.OutputValue) + @(($ini.GetEnumerator() | where key -like "OutputCustom*" | where value -notlike "").value)
$FormatCustom =  @($ini.FormatValue) + @(($ini.GetEnumerator() | where key -like "FormatCustom*" | where value -notlike "").value)


# Internet search.

function InternetSearch
{
	switch ($ComboBoxSearch.Text)
	{
		{$_ -in "Google", "All search engines", "ALL"} {Start $("https://www.google.gr/#q=" + $($TextBoxSearch.Text -replace ' ', '+'))}
		{$_ -in "Bing", "All search engines", "ALL"} {Start $("https://www.bing.com/search?q=" + $($TextBoxSearch.Text -replace ' ', '+'))}
		{$_ -in "DuckDuckGo", "All search engines", "ALL"} {Start $("https://duckduckgo.com/?q=" + $($TextBoxSearch.Text -replace ' ', '+'))}
		{$_ -in "Youtube", "All video sites", "ALL"} {Start $("https://www.youtube.com/results?search_query=" + $($TextBoxSearch.Text -replace ' ', '+'))}
		{$_ -in "Dailymotion", "All video sites", "ALL"} {Start $("http://www.dailymotion.com/en/relevance/search/" + $($TextBoxSearch.Text -replace ' ', '+'))}
		{$_ -in "Metacafe", "All video sites", "ALL"} {Start $("http://www.metacafe.com/videos_about/" + $($TextBoxSearch.Text -replace ' ', '_'))}
		{$_ -in "Vimeo", "All video sites", "ALL"} {Start $("http://vimeo.com/search?q=" + $($TextBoxSearch.Text -replace ' ', '+'))}
	}
}


# Create the options list for Youtube-dl from the gui.

function Arguments
{
#	General options
	if ($CheckBoxIgnoreErrors.IsChecked -eq $True) {$IgnoreErrors = "--ignore-errors"} else {$IgnoreErrors = $null}

#	Video selection options
	if ($CheckBoxPlaylistStart.IsChecked -eq $True) {$PlaylistStart = "--playlist-start"; $PlaylistStartValue = $TextBoxPlaylistStart.Text} else {$PlaylistStart = $PlaylistStartValue = $null}
	if ($CheckBoxPlaylistEnd.IsChecked -eq $True) {$PlaylistEnd = "--playlist-end"; $PlaylistEndValue = $TextBoxPlaylistEnd.Text} else {$PlaylistEnd = $PlaylistEndValue = $null}
	if ($CheckBoxMaxDownloads.IsChecked -eq $True) {$MaxDownloads = "--max-downloads"; $MaxDownloadsValue = $TextBoxMaxDownloads.Text} else {$MaxDownloads = $MaxDownloadsValue = $null}

	if ($CheckBoxMatchTitle.IsChecked -eq $True) {$MatchTitle = "--match-title"; $MatchTitleValue = '"{0}"' -f $TextBoxMatchTitle.Text} else {$MatchTitle = $MatchTitleValue = $null}
	if ($CheckBoxRejectTitle.IsChecked -eq $True) {$RejectTitle = "--reject-title"; $RejectTitleValue = '"{0}"' -f $TextBoxRejectTitle.Text} else {$RejectTitle = $RejectTitleValue = $null}

	if ($CheckBoxMinFilesize.IsChecked -eq $True) {$MinFilesize = "--min-filesize"; $MinFilesizeValue = $TextBoxMinFilesize.Text} else {$MinFilesize = $MinFilesizeValue = $null}
	if ($CheckBoxMaxFilesize.IsChecked -eq $True) {$MaxFilesize = "--max-filesize"; $MaxFilesizeValue = $TextBoxMaxFilesize.Text} else {$MaxFilesize = $MaxFilesizeValue = $null}

	if ($CheckBoxDate.IsChecked -eq $True) {$Date = "--date"; $DateValue = $TextBoxDate.Text} else {$Date = $DateValue = $null}
	if ($CheckBoxDateBefore.IsChecked -eq $True) {$DateBefore = "--datebefore"; $DateBeforeValue = $TextBoxDateBefore.Text} else {$DateBefore = $DateBeforeValue = $null}
	if ($CheckBoxDateAfter.IsChecked -eq $True) {$DateAfter = "--dateafter"; $DateAfterValue = $TextBoxDateAfter.Text} else {$DateAfter = $DateAfterValue = $null}

	if ($CheckBoxMinViews.IsChecked -eq $True) {$MinViews = "--min-views"; $MinViewsValue = $TextBoxMinViews.Text} else {$MinViews = $MinViewsValue = $null}
	if ($CheckBoxMaxViews.IsChecked -eq $True) {$MaxViews = "--max-views"; $MaxViewsValue = $TextBoxMaxViews.Text} else {$MaxViews = $MaxViewsValue = $null}

	if ($CheckBoxNoPlaylist.IsChecked -eq $True) {$NoPlaylist = "--no-playlist"} else {$NoPlaylist = $null}

#	Download options
	if ($CheckBoxRateLimit.IsChecked -eq $True) {$RateLimit = "--rate-limit"; $RateLimitValue = $TextBoxRateLimit.Text} else {$RateLimit = $RateLimitValue = $null}

	if ($CheckBoxPlaylistReverse.IsChecked -eq $True) {$PlaylistReverse = "--playlist-reverse"} else {$PlaylistReverse = $null}

#	Filesystem options
	if ($CheckBoxOutput.IsChecked -eq $True) {$Output = "--output"; $OutputValue = '"{0}"' -f $TextBoxOutput.Text} else {$Output = $OutputValue = $null}
	if ($CheckBoxRestrictFilenames.IsChecked -eq $True) {$RestrictFilenames = "--restrict-filenames"} else {$RestrictFilenames = $null}

	if ($CheckBoxNoOverwrites.IsChecked -eq $True) {$NoOverwrites = "--no-overwrites"} else {$NoOverwrites = $null}

#	Verbosity / simulation options

#	Workarounds

#	Video format options
	if ($CheckBoxFormat.IsChecked -eq $True) {$Format = "--format"; $FormatValue = '"{0}"' -f $TextBoxFormat.Text} else {$Format = $FormatValue = $null}
	if ($CheckBoxPreferFreeFormats.IsChecked -eq $True) {$PreferFreeFormats = "--prefer-free-formats"} else {$PreferFreeFormats = $null}

#	Subtitle options

#	Post-processing options

#	Create the argument list
	$script:ArgumentList = "$PlaylistStart $PlaylistStartValue $PlaylistEnd $PlaylistEndValue $MaxDownloads $MaxDownloadsValue $MatchTitle $MatchTitleValue $RejectTitle $RejectTitleValue $MinFilesize $MinFilesizeValue $MaxFilesize $MaxFilesizeValue $Date $DateValue $DateBefore $DateBeforeValue $DateAfter $DateAfterValue $MinViews $MinViewsValue $MaxViews $MaxViewsValue $NoPlaylist $RateLimit $RateLimitValue $PlaylistReverse $Output $OutputValue $RestrictFilenames $NoOverwrites $IgnoreErrors $Format $FormatValue $PreferFreeFormats"
	$script:ArgumentListArray = $PlaylistStart, $PlaylistStartValue, $PlaylistEnd, $PlaylistEndValue, $MaxDownloads, $MaxDownloadsValue, $MatchTitle, $MatchTitleValue, $RejectTitle, $RejectTitleValue, $MinFilesize, $MinFilesizeValue, $MaxFilesize, $MaxFilesizeValue, $Date, $DateValue, $DateBefore, $DateBeforeValue, $DateAfter, $DateAfterValue, $MinViews, $MinViewsValue, $MaxViews, $MaxViewsValue, $NoPlaylist, $RateLimit, $RateLimitValue, $PlaylistReverse, $Output, $OutputValue, $RestrictFilenames, $NoOverwrites, $IgnoreErrors, $Format, $FormatValue, $PreferFreeFormats
	$script:ArgumentListJson = $PlaylistStart, $PlaylistStartValue, $PlaylistEnd, $PlaylistEndValue, $NoPlaylist, $PlaylistReverse, $Format, $FormatValue, $PreferFreeFormats, "--dump-single-json"

	if ($TextBoxOptionsString) {$TextBoxOptionsString.Text = $(("youtube-dl " + $ArgumentList) -replace '\s+', ' ' -replace ' --', '  --')}
}


# Download and Stop functions.

function Download
{
	if (($TextBoxSavePath.Text -ne "") -and (Test-Path $TextBoxSavePath.Text -IsValid) -and (Split-Path $TextBoxSavePath.Text -IsAbsolute))
	{
		$RichTextBoxURLs.SelectAll()
		$urls = [string]$($RichTextBoxURLs.Selection.Text.Split("`r`n") | where length -gt 0)

		if ($urls.length -gt 0)
		{
			new-item -itemtype directory -path $TextBoxSavePath.Text
			cd $TextBoxSavePath.Text

			$FinalArgs = $ArgumentList + " -- " + $urls

			$script:ytdlprocess = Start-Process -FilePath $ytdlPath -ArgumentList $FinalArgs -Verbose -PassThru -NoNewWindow
		}
		else
		{
			NoUrlErrorWindow
			$Go.Content = "Download"
		}
	}
	else
	{
		SavePathErrorWindow
		$Go.Content = "Download"
	}
}

function Stop
{
	try
	{
		Stop-Process $ytdlprocess -ErrorAction Stop
	}
	catch
	{
		$null
	}
}


function Check_if_text_is_url ($text)
{
	if ($text -like "http*")
	{
		return $True
	}
	else
	{
		$TextBlockStatus.Text = "What you are trying to paste is not a URL"
		return $False
	}
}


function Load_Text
{
	$filename = $urlpath

	if ($filename) {$textstring = (Get-Content -LiteralPath $filename) -Join "`n"; $RichTextBoxURLs.Appendtext($textstring)}
}

function Save_Text
{
	$RichTextBoxURLs.SelectAll()
	$arraytext = $($RichTextBoxURLs.Selection.Text.Split("`r`n") | where length -gt 0)
	$arraytext | Out-File -LiteralPath $urlpath -Encoding UTF8
}


function Check_if_text_exists($text)
{
	$RichTextBoxURLs.SelectAll()
	$arraytext = $($RichTextBoxURLs.Selection.Text.Split("`r`n") | where length -gt 0)

	if ( ($arraytext) -and ($arraytext.Contains($text)) )
	{
		$TextBlockStatus.Text = "This URL already exists"
		return $True
	}
	return $False
}


function Append_URL($text)
{
	$RichTextBoxURLs.SelectAll()
	$lines = [System.Collections.ArrayList]$RichTextBoxURLs.Selection.Text.Split("`r`n")
	$lines.RemoveAt($lines.Count - 1)
	if ($lines[-2].Length -ne 0) {$RichTextBoxURLs.Appendtext("`n")}
	$RichTextBoxURLs.Appendtext($text + "`n")
	$TextBlockStatus.Text = ""
}


function Remove_duplicates
{
	$RichTextBoxURLs.SelectAll()
	$arraytext = $($RichTextBoxURLs.Selection.Text.Split("`r`n") | where length -gt 0)
	$arraytext_unique = $arraytext | Select-Object -Unique

	$RichTextBoxURLs.Document.Blocks.Clear(); $RichTextBoxURLs.Appendtext("`n"); $RichTextBoxURLs.Document.Blocks.FirstBlock.Margin = 0

	$textstring = $arraytext_unique -Join "`n"
	$RichTextBoxURLs.Appendtext($textstring)

	$num_of_dups = $arraytext.Count - $arraytext_unique.Count

	if ($num_of_dups -eq 0)
	{
		$TextBlockStatus.Text = "No duplicates found"
	}
	elseif ($num_of_dups -eq 1)
	{
		$TextBlockStatus.Text = "Removed 1 duplicate"
	}
	else
	{
		$TextBlockStatus.Text = "Removed $num_of_dups duplicates"
	}
}


# Nested windows.
# The Populate_RichTextBoxLicense and ShowHideLicense functions are used by the 'About' window.
function Populate_RichTextBoxLicense
{
	$RichTextBoxLicense.Document.Blocks.Clear()
	$RichTextBoxLicense.Appendtext("`n")
	$RichTextBoxLicense.Document.Blocks.FirstBlock.Margin = 0

	$RichTextBoxLicense.Appendtext("Copyright 2019, Odysseas Raftopoulos`nAll rights reserved.`n`n")
	$RichTextBoxLicense.Appendtext("Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:`n`n")
	$RichTextBoxLicense.Appendtext("1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.`n`n")
	$RichTextBoxLicense.Appendtext("2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.`n`n")
	$RichTextBoxLicense.Appendtext("THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS `"AS IS`" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.")
}

function ShowHideLicense
{
	if ($StackPanelLicense.Visibility -eq "Collapsed")
	{
		$StackPanelAbout.Visibility = "Collapsed"
		$StackPanelLicense.Visibility = "Visible"
		$ButtonShowHideLicense.Content = "Hide license"
	}
	else
	{
		$StackPanelAbout.Visibility = "Visible"
		$StackPanelLicense.Visibility = "Collapsed"
		$ButtonShowHideLicense.Content = "Show license"
	}
}

function AboutWindow
{
	$gradientA = New-LinearGradientBrush -StartPoint "0, 0.2" -EndPoint "1, 0.83" $(
		New-GradientStop -Color '#BF206DD6' -Offset 0
		New-GradientStop -Color '#80206DD6' -Offset 0.5
		New-GradientStop -Color '#20206DD6' -Offset 1
	)

	$gradientB = New-LinearGradientBrush -StartPoint "0, 0" -EndPoint "0, 1" $(
		New-GradientStop -Color '#82206DD6' -Offset 0
		New-GradientStop -Color '#B54F71DE' -Offset 0.5
		New-GradientStop -Color '#D1274ED3' -Offset 0.88
		New-GradientStop -Color '#EF0014C8' -Offset 0.96
		New-GradientStop -Color '#000014C8' -Offset 1
	)

	New-Window -Title 'About' -MinHeight 362 -MinWidth 602 -MaxHeight 362 -MaxWidth 602 -WindowStartupLocation CenterScreen -On_Loaded {Populate_RichTextBoxLicense} {
		New-DockPanel {
			New-StackPanel -Dock Top -Background $gradientA {
				New-Grid -Rows Auto -Columns Auto, Auto, * -Height 50 -Background $gradientB {
					New-TextBlock "VideoDL" -FontSize 32 -FontWeight Bold -Foreground White -Margin "20,1,0,0"
					New-TextBlock "v0.1 alpha" -FontSize 14 -Foreground White -Column 1 -Margin "14,21,0,0"
				}
			}
			New-StackPanel -Name "StackPanelAbout" -Dock Top -Margin "20,20,0,0" {
				New-TextBlock "A front end for the command line program Youtube-dl."
				New-TextBlock "Author:   Odysseas Raftopoulos" -Margin '0,20,0,0'
				New-TextBlock "This software is released under the FreeBSD license." -Margin '0,20,0,0'
				New-Grid -Rows Auto -Columns 60, Auto, Auto -Margin '0,30,0,0' {
					New-TextBlock "Repository"
					New-TextBlock ":" -Column 1
					New-TextBlock -Column 2 -Margin '14,0,0,0' -Inlines {
						New-Hyperlink "https://github.com/ody1/videodl" -NavigateUri "https://github.com/ody1/videodl" -On_RequestNavigate {Start $this.NavigateUri.ToString()}
					}
				}
				New-Grid -Rows Auto -Columns 60, Auto, Auto -Margin '0,8,0,0' {
					New-TextBlock "Releases"
					New-TextBlock ":" -Column 1
					New-TextBlock -Column 2 -Margin '14,0,0,0' -Inlines {
						New-Hyperlink "https://github.com/ody1/videodl/releases" -NavigateUri "https://github.com/ody1/videodl/releases" -On_RequestNavigate {Start $this.NavigateUri.ToString()}
					}
				}
			}
			New-StackPanel -Name "StackPanelLicense" -Visibility "Collapsed" -Dock Top -Margin "20,20,20,0" {
				New-RichTextBox | Where-Object {$_.Name = "RichTextBoxLicense"; $_.Height = 200; $_.BorderThickness = 1; $_.Background = "Transparent"; $_.VerticalScrollBarVisibility = "Auto"; $_.IsReadOnly = $True; $_}
			}
			New-Grid -Rows *, Auto -Columns Auto, *, Auto -Margin '20,0,20,20' -Dock Top {
				New-Button "Show license" -Name "ButtonShowHideLicense" -Height 21 -Width 90 -Row 1 -Column 0 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {ShowHideLicense}
				New-Button "OK" -Height 21 -Width 75 -Row 1 -Column 2 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {Close-Control}
			}
		}
	} -Show
}


function Show_Info
{
	New-Window -Title 'Instructions' -Background '#FFF5F5F5' -MinHeight 352 -MinWidth 642 -MaxHeight 610 -MaxWidth 642 -WindowStartupLocation CenterScreen -FontFamily "Segoe UI" -FontSize 12 {
		New-Grid -Rows *, Auto {
			New-ScrollViewer -VerticalScrollBarVisibility Auto -Background 'White' {
				New-StackPanel -Margin '30,0,0,8' {
					New-Grid -Rows Auto, Auto -Columns Auto -Margin '0,15,0,0' {		#### -Margin "Left, Up, Right, Down"
						New-TextBlock -FontSize 14 -FontWeight SemiBold -Text "How to download"
						New-Separator -Row 1 -Margin '0,2,0,0'
					}
					New-TextBlock -Margin '0,4,0,0' -Text "Copy video URLs from the browser and paste them in the URL textbox."
					New-TextBlock -Margin '0,8,0,0' -Text "When you are ready, press the 'Download' button."
					New-TextBlock -Margin '0,8,0,0' -Text "If you add more URLs after the download has started, press 'Stop' and 'Download' again."

					New-Grid -Rows Auto, Auto -Columns Auto -Margin '0,15,0,0' {
						New-TextBlock -FontSize 14 -FontWeight SemiBold -Text "'Append URL' button"
						New-Separator -Row 1 -Margin '0,2,0,0'
					}
					New-TextBlock -Margin '0,4,0,0' -Text "Use the 'Append URL' button to add the copied URL in the URL textbox."
					New-TextBlock -Margin '0,8,0,0' -Text "It is recommended to use the 'Append URL' button than do it manually, because`nthis checks if the text is indeed a URL and if the URL is is not already added."

					New-Grid -Rows Auto, Auto -Columns Auto -Margin '0,15,0,0' {
						New-TextBlock -FontSize 14 -FontWeight SemiBold -Text "'Remove duplicates' button"
						New-Separator -Row 1 -Margin '0,2,0,0'
					}
					New-TextBlock -Margin '0,4,0,0' -Text "If you have added many URLs manually, use the 'Remove duplicates' button.`nThis removes any duplicates as well as any empty lines in the URL textbox."

					New-Grid -Rows Auto, Auto -Columns Auto -Margin '0,15,0,0' {
						New-TextBlock -FontSize 14 -FontWeight SemiBold -Text "Clear URLs"
						New-Separator -Row 1 -Margin '0,2,0,0'
					}
					New-TextBlock -Margin '0,4,0,0' -Text "To delete everything in the URL textbox, press 'Clear URLs' in the menu."

					New-Grid -Rows Auto, Auto -Columns Auto -Margin '0,15,0,0' {
						New-TextBlock -FontSize 14 -FontWeight SemiBold -Text "Keyboard shortcuts"
						New-Separator -Row 1 -Margin '0,2,0,0'
					}
					New-TextBlock -Margin '0,4,0,0' -Text "Click inside the URL textbox. Then you can use the following keyboard shortcuts:"
					New-TextBlock -Margin '0,2,0,0' -Text "Ctrl+A:	Select all"
					New-TextBlock -Margin '0,2,0,0' -Text "Ctrl+X:	Cut"
					New-TextBlock -Margin '0,2,0,0' -Text "Ctrl+C:	Copy"
					New-TextBlock -Margin '0,2,0,0' -Text "Ctrl+V:	Paste"
					New-TextBlock -Margin '0,2,0,0' -Text "Ctrl+Z:	Undo"
					New-TextBlock -Margin '0,2,0,0' -Text "Ctrl+Y:	Redo"
				}
			}
			New-Button "OK" -Row 1 -Height 21 -Width 75 -HorizontalAlignment Center -Margin '0,20,0,20' -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {Close-Control}
		}
	} -Show
}


function SavePathErrorWindow
{
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	[System.Windows.Forms.MessageBox]::Show("Save path is not valid","Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}

function NoUrlErrorWindow
{
	[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
	[System.Windows.Forms.MessageBox]::Show("You need to provide al least one url","Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}


# ShowUI code.
New-Window -ControlName 'MainWindow' -Title 'VideoDL' -Background '#FFF5F5F5' -Height 580 -Width 712 -MinHeight 580 -MinWidth 712 -WindowStartupLocation CenterScreen -FontFamily "Segoe UI" -FontSize 11.5 -UseLayoutRounding -On_Initialized {Arguments; $RichTextBoxURLs.Document.Blocks.FirstBlock.Margin = 0; Load_Text} -On_Closing {Stop; Save_Text} {
	New-DockPanel {
		New-Menu -Height 22 -Dock Top {
			New-MenuItem "Console" {
				New-MenuItem "Clear console" -On_Click {cls}
				New-MenuItem "Show/hide console" -On_Click {ShowHideConsole}
			}
			New-MenuItem "Tools" {
				New-MenuItem "Go to Youtube-dl directory" -On_Click {Invoke-Item (Split-Path $ytdlPath)}
				New-MenuItem "Go to FFmpeg directory" -On_Click {Invoke-Item (Split-Path (Get-Command ffmpeg.exe).Path)}
			}
			New-MenuItem "Clear URLs" -On_Click {$RichTextBoxURLs.Document.Blocks.Clear(); $RichTextBoxURLs.Appendtext("`n"); $RichTextBoxURLs.Document.Blocks.FirstBlock.Margin = 0}
			New-MenuItem "Help" {
				New-MenuItem "Update Youtube-dl" -On_Click {Start-Process -FilePath $ytdlPath --update -Verbose -NoNewWindow}
				New-Separator -Margin "0,0,0,0"
				New-MenuItem "Youtube-dl homepage" -On_Click {Start https://rg3.github.io/youtube-dl/ }
				New-MenuItem "Youtube-dl online documentation" -On_Click {Start https://github.com/rg3/youtube-dl/blob/master/README.md }
				New-MenuItem "Youtube-dl github issue tracker" -On_Click {Start https://github.com/rg3/youtube-dl/issues }
				New-MenuItem "Youtube-dl supported sites" -On_Click {Start https://rg3.github.io/youtube-dl/supportedsites.html }
				New-Separator -Margin "0,0,0,0"
				New-MenuItem "About" -On_Click {AboutWindow}
			}
		} # Here ends the Menu.

		New-Grid -Margin "8,12,12,10" -Height 21 -Columns Auto, 100, *, 25 -Dock Top {		#### -Margin "Left, Up, Right, Down"
			New-Label "Search" -Name "CheckBoxSavePath" -Column 0 -Margin "0,-2,0,0"
			New-ComboBox -Name "ComboBoxSearch" -Column 1 -SelectedIndex 3 -Items "Google", "Bing", "DuckDuckGo", "Youtube", "Dailymotion", "Metacafe", "Vimeo", "All search engines", "All video sites", "ALL"
			New-TextBox -Name "TextBoxSearch" -Column 2 -Margin "6,0,10,0"
			New-Button "Go" -Name "ButtonBrowse" -Column 3 -Width 25 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -ToolTip "Search..." -On_Click {InternetSearch}
		} # Here ends the Search Grid.

		New-Grid -Margin "12,0,12,4" -Columns Auto, Auto, *, 25 -Dock Top {
			New-CheckBox "Restrict filenames" -Name "CheckBoxRestrictFilenames" -Margin "0,3,24,0" -IsChecked:$(if ($ini.RestrictFilenames -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--restrict-filenames`nRestrict filenames to only ASCII characters.`nAvoids special characters and spaces`nbecome underscores."
			New-CheckBox "Output" -Name "CheckBoxOutput" -Column 1 -Margin "0,3,0,0" -IsChecked:$(if ($ini.Output -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "-o, --output TEMPLATE`nOutput filename template.`n`n%(title)s:			Video title`n%(ext)s:			Filename extension`n%(id)s:			Video ID`n%(uploader)s:		Uploader name`n%(uploader_id)s:		Uploader nickname`n%(autonumber)s:		Automatically incremented number`n%(format)s:		Format description`n%(format_id)s:		Unique ID of the format`n%(upload_date)s:		Upload date (YYYYMMDD)`n%(extractor)s:		Provider (youtube, metacafe, etc)`n%(playlist_title):		Playlist title`n%(playlist_id)s:		Playlist ID`n%(playlist)s:		Playlist title if present, ID otherwise`n%(playlist_index)s:		Position in the playlist`n%(width)s:		Width of the video format`n%(height)s:		Height of the video format`n%(resolution)s:		Resolution of the video format`n%%:			Literal percent`n`nThe default template is %(title)s-%(id)s.%(ext)s`n`nCan also be used to download to a different directory, for example:`n--output '/my/downloads/%(uploader)s/%(title)s-%(id)s.%(ext)s'"
			New-TextBox -Name "TextBoxOutput" -Column 2 -Margin "6,0,10,0" -Text $ini.OutputValue -On_TextChanged {Arguments}
			New-ComboBox -Name "ComboBoxOutputCustom" -Column 3 -Items $OutputCustom -On_SelectionChanged {$TextBoxOutput.Text = $this.SelectedValue} -ToolTip "These are the output templates`nthat you make in the ini file."
		} # Here ends the Output Options Grid.

		New-Grid -Margin "12,0,12,8" -Columns Auto, Auto, *, 25 -Dock Top {
			New-CheckBox "Prefer free formats" -Name "CheckBoxPreferFreeFormats" -Column 0 -Margin "0,3,18,0" -IsChecked:$(if ($ini.PreferFreeFormats -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--prefer-free-formats`nPrefer free video formats unless`na specific one is requested."
			New-CheckBox "Format" -Name "CheckBoxFormat" -Column 1 -Margin "0,3,0,0" -IsChecked:$(if ($ini.Format -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "-f, --format FORMAT`nVideo format code, specify the order of`npreference using slashes, as in -f 22/17/18.`n`nInstead of format codes, you can`nselect by extension for the extensions`naac, m4a, mp3, mp4, ogg, wav, webm.`n`nYou can also use the special names`n`"best`", `"bestvideo`", `"bestaudio`", `"worst`".`n`nYou can filter the video results`nby putting a condition in brackets,`nas in -f `"best[height=720]`" (or -f `"[filesize>10M]`").`nThis works for:`nfilesize, height, width, tbr, abr, vbr, asr and fps`nwith the comparisons <, <=, >, >=, =, !=`nand for:`next, acodec, vcodec, container and protocol`nwith the comparisons =, !=.`n`nFormats for which the value is not known`nare excluded unless you put a question mark`n(?) after the operator.`n`nYou can combine format filters, so`n-f `"[height <=?720][tbr>500]`" selects up to 720p`nvideos (or videos where the height is not known)`nwith a bitrate of at least 500 KBit/s.`nBy default, youtube-dl will pick the best quality.`n`nUse commas to download multiple audio formats,`nsuch as -f 136/137/mp4/bestvideo,140/m4a/bestaudio.`n`nYou can merge the video and audio of`ntwo formats into a single file using`n-f <video-format>+<audio-format>`n(requires ffmpeg or avconv),`nfor example -f bestvideo+bestaudio."
			New-TextBox -Name "TextBoxFormat" -Column 2 -Margin "6,0,10,0" -Text $ini.FormatValue -On_TextChanged {Arguments}
			New-ComboBox -Name "ComboBoxFormatCustom" -Column 3 -Items $FormatCustom -On_SelectionChanged {$TextBoxFormat.Text = $this.SelectedValue} -ToolTip "These are the settings for the Format`noption that you create in the ini file."
		} # Here ends the Format Options Grid.

		New-Grid -Margin "12,0,12,8" -Columns Auto, Auto -Dock Top {
			New-CheckBox "No playlist" -Name "CheckBoxNoPlaylist" -Margin "0,0,8,0" -IsChecked:$(if ($ini.NoPlaylist -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--no-playlist`nIf the URL refers to a video and a`nplaylist, download only the video."
			New-CheckBox "Playlist reverse" -Name "CheckBoxPlaylistReverse" -Column 1 -Margin "8,0,0,0" -IsChecked:$(if ($ini.PlaylistReverse -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--playlist-reverse`nDownload playlist videos in reverse order."
		} # Here ends the URL Grid.

		New-Grid -Margin "12,0,12,4" -Columns Auto, * -Rows Auto, *, Auto, Auto, Auto -Dock Top {
			New-GroupBox "Video selection options" -Column 0 -Row 0 {
				New-StackPanel -Orientation Vertical {
					New-Grid -Margin "0,0,0,6" -Columns 105, * -Rows Auto, Auto, Auto {
						New-CheckBox "Playlist start" -Name "CheckBoxPlaylistStart" -Margin "0,3,0,2" -IsChecked:$(if ($ini.PlaylistStart -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--playlist-start NUMBER`nPlaylist video to start at (default is 1)."
						New-TextBox -Name "TextBoxPlaylistStart" -Column 1 -Margin "0,0,0,2" -Width 36 -Text $ini.PlaylistStartValue -On_TextChanged {Arguments}

						New-CheckBox "Playlist end" -Name "CheckBoxPlaylistEnd" -Row 1 -Margin "0,3,0,2" -IsChecked:$(if ($ini.PlaylistEnd -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--playlist-end NUMBER`nPlaylist video to end at (default is last).`n`nThe playlist options also work with channels.`nFor example, to get the 10 most recent`nvideos of a channel just set this to 10."
						New-TextBox -Name "TextBoxPlaylistEnd" -Column 1 -Row 1 -Margin "0,0,0,2" -Width 36 -Text $ini.PlaylistEndValue -On_TextChanged {Arguments}

						New-CheckBox "Max downloads" -Name "CheckBoxMaxDownloads" -Row 2 -Margin "0,3,0,2" -IsChecked:$(if ($ini.MaxDownloads -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--max-downloads NUMBER`nAbort after downloading NUMBER files."
						New-TextBox -Name "TextBoxMaxDownloads" -Column 1 -Row 2 -Margin "0,0,0,2" -Width 36 -Text $ini.MaxDownloadsValue -On_TextChanged {Arguments}
					}
					New-Grid -Margin "0,0,0,6" -Columns 51, * -Rows Auto, Auto {
						New-CheckBox "Match" -Name "CheckBoxMatchTitle" -Margin "0,3,0,2" -IsChecked:$(if ($ini.MatchTitle -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--match-title REGEX`nDownload only matching titles`n(regex or caseless sub-string)."
						New-TextBox -Name "TextBoxMatchTitle" -Column 1 -Margin "0,0,0,2" -Width 90 -Text $ini.MatchTitleValue -On_TextChanged {Arguments}

						New-CheckBox "Reject" -Name "CheckBoxRejectTitle" -Row 1 -Margin "0,3,0,2" -IsChecked:$(if ($ini.RejectTitle -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--reject-title REGEX`nSkip download for matching titles`n(regex or caseless sub-string)."
						New-TextBox -Name "TextBoxRejectTitle" -Column 1 -Row 1 -Margin "0,0,0,2" -Width 90 -Text $ini.RejectTitleValue -On_TextChanged {Arguments}
					}
					New-Grid -Margin "0,0,0,6" -Columns 81, * -Rows Auto, Auto {
						New-CheckBox "Min filesize" -Name "CheckBoxMinFilesize" -Margin "0,3,0,2" -IsChecked:$(if ($ini.MinFilesize -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--min-filesize SIZE`nDo not download any videos smaller`nthan SIZE (e.g. 50k or 44.6m)."
						New-TextBox -Name "TextBoxMinFilesize" -Column 1 -Margin "0,0,0,2" -Width 60 -Text $ini.MinFilesizeValue -On_TextChanged {Arguments}

						New-CheckBox "Max filesize" -Name "CheckBoxMaxFilesize" -Row 1 -Margin "0,3,0,2" -IsChecked:$(if ($ini.MaxFilesize -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--max-filesize SIZE`nDo not download any videos larger`nthan SIZE (e.g. 50k or 44.6m)."
						New-TextBox -Name "TextBoxMaxFilesize" -Column 1 -Row 1 -Margin "0,0,0,2" -Width 60 -Text $ini.MaxFilesizeValue -On_TextChanged {Arguments}
					}
					New-Grid -Margin "0,0,0,6" -Columns 81, * -Rows Auto, Auto, Auto {
						New-CheckBox "Date" -Name "CheckBoxDate" -Margin "0,3,0,2" -IsChecked:$(if ($ini.Date -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--date DATE`nDownload only videos uploaded in this date.`n`nThe three Date options accept dates in two formats:`nAbsolute dates: YYYYMMDD.`nRelative dates: (now|today)[+-][0-9](day|week|month|year)(s)?`n`nExample:`nDownload only the videos uploaded on January 29, 2011`nyoutube-dl --date 20110129"
						New-TextBox -Name "TextBoxDate" -Column 1 -Margin "0,0,0,2" -Width 60 -Text $ini.DateValue -On_TextChanged {Arguments}

						New-CheckBox "Date before" -Name "CheckBoxDateBefore" -Row 1 -Margin "0,3,0,2" -IsChecked:$(if ($ini.DateBefore -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--datebefore DATE`nDownload only videos uploaded on or before`nthis date (i.e. inclusive).`n`nExample:`nDownload only the videos uploaded between September, 2013 and May, 2014`nyoutube-dl --dateafter 20130901 --datebefore 20140531"
						New-TextBox -Name "TextBoxDateBefore" -Column 1 -Row 1 -Margin "0,0,0,2" -Width 60 -Text $ini.DateBeforeValue -On_TextChanged {Arguments}

						New-CheckBox "Date after" -Name "CheckBoxDateAfter" -Row 2 -Margin "0,3,0,2" -IsChecked:$(if ($ini.DateAfter -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--dateafter DATE`nDownload only videos uploaded on or after`nthis date (i.e. inclusive).`n`nExample:`nDownload only the videos uploaded in the last 6 months`nyoutube-dl --dateafter now-6months"
						New-TextBox -Name "TextBoxDateAfter" -Column 1 -Row 2 -Margin "0,0,0,2" -Width 60 -Text $ini.DateAfterValue -On_TextChanged {Arguments}
					}
					New-Grid -Margin "0,0,0,6" -Columns 73, * -Rows Auto, Auto {
						New-CheckBox "Min views" -Name "CheckBoxMinViews" -Margin "0,3,0,2" -IsChecked:$(if ($ini.MinViews -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--min-views COUNT`nDo not download any videos with`nless than COUNT views."
						New-TextBox -Name "TextBoxMinViews" -Column 1 -Margin "0,0,0,2" -Width 72 -Text $ini.MinViewsValue -On_TextChanged {Arguments}

						New-CheckBox "Max views" -Name "CheckBoxMaxViews" -Row 1 -Margin "0,3,0,2" -IsChecked:$(if ($ini.MaxViews -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "--max-views COUNT`nDo not download any videos with`nmore than COUNT views."
						New-TextBox -Name "TextBoxMaxViews" -Column 1 -Row 1 -Margin "0,0,0,2" -Width 72 -Text $ini.MaxViewsValue -On_TextChanged {Arguments}
					}
				}
			}

			New-GroupBox "Video URLs" -Margin "8,0,0,0" -RowSpan 2 -Column 1 -Row 0 {		#### -Margin "Left, Up, Right, Down"
				New-Grid -Columns * -Rows Auto, *, Auto {
					New-Grid -Columns Auto, Auto, *, Auto, Auto -Rows Auto -Margin "0,6,0,4" {
						New-Button "Append URL" -Height 21 -Width 90 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {
							if ( (Check_if_text_is_url $([Windows.Clipboard]::GetText())) -and (!$(Check_if_text_exists $([Windows.Clipboard]::GetText()))) ) {Append_URL([Windows.Clipboard]::GetText())}
						}
						New-Button "Remove duplicates" -Margin "8,0,0,0" -Column 1 -Height 21 -Width 126 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {Remove_duplicates}
						New-ComboBox -Name "ComboBoxFavoriteChannels" -Height 21 -Width 25 -Margin "8,0,0,0" -Column 3 -Items $FavoriteChannels -On_SelectionChanged {$RichTextBoxURLs.Appendtext($this.SelectedValue + "`n")} -ToolTip "Select a URL to copy it to the text box in the left.`nPut your favorite channels in the ini file."
						New-Button "Instructions" -Margin "8,0,0,0" -Column 4 -Height 21 -Width 90 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {Show_Info}
					}

					New-Grid -Margin "0,0,0,0" -Column 1 -Row 1 -Columns * {
						New-RichTextBox | where-object { $_.Name = "RichTextBoxURLs"; $_.BorderThickness = 2; $_.VerticalScrollBarVisibility = "Visible"; $_ }
					}

					New-Grid -Row 2 -Columns Auto, *, Auto -Rows Auto {
						New-TextBlock "Status:  " -Margin "6,2,0,0" -FontSize 20
						New-TextBlock "" -Name "TextBlockStatus" -Margin "0,2,0,0" -Column 1 -FontSize 20 -Foreground "Red"
						New-Button "Clear" -Margin "0,6,0,0" -Column 2 -Height 18 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {$TextBlockStatus.Text = ""}
					}
				}
			}

			New-Grid -Margin "0,4,0,8" -ColumnSpan 2 -Row 3 -Columns Auto, Auto, Auto, *, Auto, Auto {
				New-CheckBox "No overwrites" -Name "CheckBoxNoOverwrites" -Column 0 -Margin "0,3,18,0" -IsChecked:$(if ($ini.NoOverwrites -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip "-w, --no-overwrites`nDo not overwrite files."
				New-CheckBox "Ignore errors" -Name "CheckBoxIgnoreErrors" -Column 1 -Margin "0,3,18,0" -IsChecked:$(if ($ini.IgnoreErrors -eq "True") {$true} else {$false}) -On_Click {Arguments} -ToolTip ("--ignore-errors`nContinue on download errors, for example`nto skip unavailable videos in a playlist.")
				New-Label "Save path" -Column 2 -Margin "12,-2,0,0"
				New-TextBox -Name "TextBoxSavePath" -Column 3 -Height 21 -Margin "1,0,0,2" -Text $ini.SavePath
				New-Button "..." -Name "ButtonBrowse" -Column 4 -Height 21 -Width 25 -FontSize 12.5 -Margin "10,0,0,2" -Background $ButtonBackColor -BorderBrush '#FFACACAC' -ToolTip "Browse for folder." -On_Click {
					if (!$this.Tag) {$this.Tag = new-object Windows.Forms.FolderBrowserDialog}
					if ($TextBoxSavePath.Text) {$this.Tag.SelectedPath = $TextBoxSavePath.Text}
					if ($this.Tag.ShowDialog() -eq "OK") {$TextBoxSavePath.Text = $this.Tag.SelectedPath}
					}
				New-Button "Open" -Margin "8,0,0,2" -Column 5 -Height 21 -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {try {Start $($TextBoxSavePath.Text + "\" -replace "\\+", "\") -ErrorAction Stop} catch {Write-Warning "Folder doesn't exist"}}
			}

			New-Grid -Margin "0,0,0,9" -Height 53 -ColumnSpan 2 -Row 4 -Columns *, Auto {
				New-TextBox -Name "TextBoxOptionsString" -BorderThickness 0.8 -TextWrapping "Wrap" -VerticalScrollBarVisibility "Auto" -IsReadOnly
				New-Button -Content "Download" -Name "Go" -Column 1 -Width 80 -Margin "10,10,0,10" -Background $ButtonBackColor -BorderBrush '#FFACACAC' -On_Click {switch ($Go.Content) {"Download" {$Go.Content = "Stop"; Save_Text; Download}; "Stop" {$Go.Content = "Download"; Stop}}}
			}
		} # Here ends the Center Grid.
	} # Here ends the DockPanel under MainWindow.
} -Show

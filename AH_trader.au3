#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.12.0
 Author:         Khasuist


#ce ----------------------------------------------------------------------------

;#include <..\LightningHalls\GlobalVarsForPlayer.au3>
;#include <Color.au3>
;#include <..\LightningHalls\playerFunctions.au3>
;#include <..\LightningHalls\PFstarter.au3>
;#include <..\LightningHalls\realmdictionary.au3>
;#include <..\LightningHalls\player_lh.au3>

Global $WinName = "World of Warcraft"


Opt("PixelCoordMode", 2) ;Отсчет координат пикселей от левого верхнего угла клиентской части окна
Opt("MouseCoordMode", 2) ;Отсчет координат мыши от левого верхнего угла клиентской части окна

AutoItWinSetTitle("Notepad")
$hwnd = WinGetHandle($WinName)
WinActivate($hwnd)
#cs
;client size
If WinExists("World of Warcraft") Then
	$aWowClientSize = WinGetClientSize("World of Warcraft")
	If $aWowClientSize[0]<>972 Then
		WinMove ($hwnd, "text", Default, Default , 980 , 756)
	EndIf
EndIf
#ce

;LoadSettings()
;CloseSameWindows()
;SaveLog("start")
GetItemsListAndAhDataFromWOWuction()
;start WOW and go
;If not WinExists("World of Warcraft") Then StartWowClient()
;Message("StartWowClient complete. Done")
#cs
while true
	If IAm___() Then
		$legalZone=MyZone()
		CheckStateOfToon()
		Message("I am in ___")
		PlayFile("___.txt", 0)
	EndIf
	
	CheckStateWowClient()
	Sleep(500)
wend
; ----------------------------------------------------------------------------------------------------------------------------------------------------------
#ce
Func GetItemsListAndAhDataFromWOWuction()
	; inspect paths WOW addons
	local $wowFolder
	local $emptyVariable
	if FileExists("D:\World of Warcraft\Wow.exe") Then $wowFolder = "D:\"
	if FileExists("E:\World of Warcraft\Wow.exe") Then $wowFolder = "E:\"
	if FileExists("Z:\World of Warcraft\Wow.exe") Then $wowFolder = "Z:\"
	if $wowFolder == $emptyVariable Then MsgBox(0, "", "WOW FOLDER NOT FOUND !!!")
	local $myAddonDir = $wowFolder & "World of Warcraft\Interface\AddOns\AH_trader"

	; inspect paths Dropbox		D:\Dropbox\!_AuIt_script\WOWproj\AH_trader\AH_trader\listID.lua
	local $dropboxDir
	if FileExists("D:\Dropbox\!_AuIt_script\WOWproj\AH_trader\AH_trader\listID.lua") Then $dropboxDir = "D:\"
	if FileExists("E:\Dropbox\!_AuIt_script\WOWproj\AH_trader\AH_trader\listID.lua") Then $dropboxDir = "E:\"
	if FileExists("Z:\Dropbox\!_AuIt_script\WOWproj\AH_trader\AH_trader\listID.lua") Then $dropboxDir = "Z:\"
	if $dropboxDir == $emptyVariable Then MsgBox(0, "", "DROPBOX FOLDER NOT FOUND !!!")
	local $dropboxAddonDir = $dropboxDir & "Dropbox\!_AuIt_script\WOWproj\AH_trader\AH_trader"

	; copy listID.lua into folder WOWaddons\my addon
	local $status = FileCopy($dropboxAddonDir & "\listID.lua", $myAddonDir & "\listID.lua", 9) ; 1 = rewrite existing file  9 = create folders and rewrite files
	if $status == 0 Then MsgBox(0, "", "THE listID.lua from DROPBOX NOT COPIED !!!")

	; get AH data from WOWuction.com and put into folder WOWaddons\my addon
	local $region = "eu" ; load from AHSettings.ini												<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< !  !  !   !!!  !!!  !!!
	local $SvejevatelDush = "%D1%81%D0%B2%D0%B5%D0%B6%D0%B5%D0%B2%D0%B0%D1%82%D0%B5%D0%BB%D1%8C-%D0%B4%D1%83%D1%88" ; свежеватель душ
	local $Drakonomor = "%D0%B4%D1%80%D0%B0%D0%BA%D0%BE%D0%BD%D0%BE%D0%BC%D0%BE%D1%80"	; дракономор
	local $Gordunni = "%D0%B3%D0%BE%D1%80%D0%B4%D1%83%D0%BD%D0%BD%D0%B8"	; гордунни
	local $Cherniyshram = "%D1%87%D0%B5%D1%80%D0%BD%D1%8B%D0%B9+%D1%88%D1%80%D0%B0%D0%BC" ; черный шрам
	local $realm = $Gordunni ; load from AHSettings.ini							<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< !  !  !   !!!  !!!  !!!
	
	local $EU_WOWuctionDataURL="http://www.wowuction.com/eu/" & $realm & "/horde/Tools/GetTSMDataStatic?dl=true&token=oPsN_5nocV4RmXj5nK56Ig2"
	local $US_WOWuctionDataURL="http://www.wowuction.com/us/" & $realm & "/horde/Tools/GetTSMDataStatic?dl=true&token=oPsN_5nocV4RmXj5nK56Ig2"
	if $region == "eu" then $WOWuctionDataURL = $EU_WOWuctionDataURL
	if $region == "us" then $WOWuctionDataURL = $US_WOWuctionDataURL
	InetGet($WOWuctionDataURL, $myAddonDir & "\ahdata_wowuction.lua")
EndFunc
#!/bin/bash

# Secure Token
# Hypoport hub SE -=- Mirko Steinbrecher
# Created on 20.06.2024

# This script creates a secure token to enable FileVault.

# inspired by the manageSecureTokens script from TravellingTechGuy and Bootstrap-Token-Escrow & FileVault Personal Recovery Key Reissue from robjschroeder
# thx @bartreardon for swiftDialog

# Variables

# Script Version
scriptVersion="1.3"

# Banner image for message
BannerImage="${4:-"https://website.com/pic.jpg"}"

# More Information Button shown in message
infotext="${5:-"Contact"}"
infolink="${6:-"https://website.com/help"}"

# IT Support Variables - Use these if the default text is fine but you want your org's info inserted instead
supportTeamName="IT Name"
supportTeamPhone="Number"
supportTeamEmail="servicedesk@mail.de"
supportTeamWebsite="https://website.com"
supportInformation="${8:-"**${supportTeamName}** via **Phone:** ${supportTeamPhone} by **Email:** ${supportTeamEmail} or via **Internet**: ${supportTeamWebsite}"}"

# Swift Dialog icon to be displayed in message
icon="${7:-"/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns"}"

# SwiftDialog Path
dialogApp="/usr/local/bin/dialog"

# Get the logged in user's name
userName=$(/bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/&&!/loginwindow/{print $3}')

CurrentUser=$(stat -f%Su /dev/console)

loggedInUser=$(dscl . -read /Users/"$CurrentUser" RealName | tail -1 | cut -c 2-)

# Messages shown to the user in the dialog when prompting for password
message="## Secure Token\n\nYour secure token has not been issued yet.
This token is used to enable FileVault.\n\n
Please enter your Mac password to issue the secure token."

# Messages shown to the user in the dialog when prompting for a wrong password
forgotMessage="## Secure Token\n\nYour secure token has not been issued yet.
This token is used to enable FileVault.\n\n ### Incorrect password, please try again:"

# The body of the message that will be displayed if a password failure occurs.
FAIL_MESSAGE_Pass="## Check your password and try again.\n\nIf the problem persists, please contact $supportInformation."

# The body of the message that will be displayed if a secure token failure occurs.
FAIL_MESSAGE_SECURE="## Secure token was not issued.\n\nIf the problem persists, please contact $supportInformation."

# The body of the message that will be displayed if the secure token is successfully issued.
ALREADY_MESSAGE="## Secure token was not issued.\n\nYour Mac already has a secure token."

# The body of the message that will be displayed if the secure token is successfully issued.
SUCCESS_MESSAGE="## Secure token was successfully issued.\n\nRestart your Mac immediately and enter your Mac password again when it restarts."

# Main dialog
dialogCMD="$dialogApp \
--title \"none\" \
--bannerimage \"$BannerImage\" \
--message \"$message\" \
--button1text \"Submit\" \
--icon "${icon}" \
--infobuttontext \"${infotext}\" \
--infobuttonaction "${infolink}" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \
--textfield \"Enter password\",secure,required"

# Forgot password dialog
dialogForgotCMD="$dialogApp \
--title \"none\" \
--bannerimage \"$BannerImage\" \
--message \"$forgotMessage\" \
--button1text \"Submit\" \
--icon "${icon}" \
--infobuttontext \"${infotext}\" \
--infobuttonaction "${infolink}" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \
--textfield \"Enter password\",secure,required"

# Error dialog Password
dialogErrorPass="$dialogApp \
--title \"none\" \
--bannerimage \"$BannerImage\" \
--message \"$FAIL_MESSAGE_Pass\" \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \ "

# Error dialog Secure
dialogErrorSecure="$dialogApp \
--title \"none\" \
--bannerimage \"$BannerImage\" \
--message \"$FAIL_MESSAGE_SECURE\" \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \ "

# Already escrowed Dialog
dialogAlreadyEscrowed="$dialogApp \
--title \"none\" \
--bannerimage \"$BannerImage\" \
--message \"$ALREADY_MESSAGE\" \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \ "

# Success Dialog
dialogSuccess="$dialogApp \
--title \"none\" \
--bannerimage \"$BannerImage\" \
--message \"$SUCCESS_MESSAGE\" \
--button1text \"Close\" \
--infotext \"$scriptVersion\" \
--messagefont 'size=14' \
--position 'centre' \
--ontop \
--moveable \ "

## Counter for Attempts
try=0
maxTry=2

## Check to see if the secure token is already escrowed
tokenCheck=$(sysadminctl -secureTokenStatus "$userName")
expectedStatus="Secure token is ENABLED for user $loggedInUser"
if [ "${tokenCheck}" != "${expectedStatus}" ]; then
echo "The secure token is already escrowed."
echo "${tokenCheck}"
eval "$dialogAlreadyEscrowed"
exit 4
fi

# Display a branded prompt explaining the password prompt.
echo "Alerting user $userName about incoming password prompt..."
userPass=$(eval "$dialogCMD" | grep "Enter password" | awk -F " : " '{print $NF}')

# Thanks to James Barclay (@futureimperfect) for this password validation loop.
TRY=1
until /usr/bin/dscl /Search -authonly "$userName" "${userPass}" &>/dev/null; do
	(( TRY++ ))
	echo "Prompting $userName for their Mac password (attempt $TRY)..."
	userPass=$(eval "$dialogForgotCMD" | grep "Enter password" | awk -F " : " '{print $NF}')
	if (( TRY >= 5 )); then
		echo "[ERROR] Password prompt unsuccessful after 5 attempts. Displaying \"forgot password\" message..."
		eval "$dialogErrorPass"
		exit 1
	fi
done
echo "Successfully prompted for Mac password."
sysadminctl interactive -secureTokenOn "$userName" -password "$userPass"
echo "Escrowing secure token"

# Check to ensure token was escrowed
if [[ $("/usr/sbin/sysadminctl" -secureTokenStatus "$userName" 2>&1) =~ "ENABLED" ]]; then
  userToken="true"
  	echo "Secure token is $userToken and escrowed for $userName"
    eval "$dialogSuccess"
    exit 0
  else
  userToken="false"
  echo "Secure token is $userToken and NOT escrowed for $userName"
	eval "$dialogErrorSecure"
  fi
	exit 4

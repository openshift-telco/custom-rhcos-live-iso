#!/bin/bash
source ~/set-environment

IGN_ISO_TEMPLATE=iso.ign.template
IGN_ISO_OUTPUT=iso.ign
IGN_NODE_CONFIG=config.ign
LIVE_ISO_SCRIPT=first-boot-live-iso.sh

if [[ ! -f "$SSH_PUB_KEY_PATH" ]]; then
    echo "Missing ssh public key $SSH_PUB_KEY_PATH"
    exit 1
fi

if [[ ! -f "$IGN_ISO_TEMPLATE" ]]; then
    echo "Missing $IGN_ISO_TEMPLATE"
    exit 1
fi

if [[ -f "$IGN_NODE_CONFIG" ]]; then
    ignition_file=$(cat "$IGN_NODE_CONFIG" | base64 -w0)
else
    echo "Missing $IGN_NODE_CONFIG"
    exit 1
fi

if [[ -f "$LIVE_ISO_SCRIPT" ]]; then
    iso_script=$(cat "$LIVE_ISO_SCRIPT" | base64 -w0)
else
    echo "Missing $LIVE_ISO_SCRIPT"
    exit 1
fi

# Load SSH as valid JSON file and merge it
SSH_KEY=$( echo "{'passwd':{'users':[{'name':'core','sshAuthorizedKeys':['$(cat $SSH_PUB_KEY_PATH)']}]}}" | sed 's/'\''/"/g' )
cat iso.ign.template | jq -s ".[0] * $SSH_KEY" > $IGN_ISO_OUTPUT-ssh

# Embed node ignition file (this procedure work around the size of rendered ign files)
IGNITION_FILE=$ignition_file
IGN_EMBED_JSON=$( echo "{'source':'data:text/plain;charset=utf-8;base64,$IGNITION_FILE'}" | sed 's/'\''/"/g'  )
echo "
{'storage': {
    'files':[     {
                'contents': {
                    'source': 'data:text/plain;charset=utf-8;base64,$IGNITION_FILE',
                    'verification': {}
                },
                'filesystem': 'root',
                'mode': 420,
                'overwrite': true,
                'path': '/root/config.ign'
            }
        ]
    }
} " | sed 's/'\''/"/g' | jq -c . > foo.json 

jq -s '.[0].storage.files[1]=.[1].storage.files[0] | .[0]' $IGN_ISO_OUTPUT-ssh foo.json | jq -c . > $IGN_ISO_OUTPUT-ign

# embed ISO script (assuming small script, otherwise previous procedure required)
ISO_SCRIPT=$iso_script
sed "s/ISO_SCRIPT/$iso_script/g" $IGN_ISO_OUTPUT-ign >  $IGN_ISO_OUTPUT

#
# END OF FILE
#
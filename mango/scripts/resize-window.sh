#!/usr/bin/env bash

# Get active client info
client_info=$(mmsg get focusing-client)
if [ -z "$client_info" ] || [ "$client_info" = "null" ]; then
    exit 0
fi

is_floating=$(echo "$client_info" | jq -r '.is_floating')
monitor=$(echo "$client_info" | jq -r '.monitor')

direction=$1 # 'left', 'down', 'up', or 'right'

if [ "$is_floating" = "true" ]; then
    # For floating windows, use smartresizewin
    mmsg dispatch "smartresizewin,$direction"
else
    # For tiled windows, check layout
    layout_symbol=$(mmsg get monitor "$monitor" | jq -r '.layout_symbol')
    case "$layout_symbol" in
        "S"|"VS"|"scroller"|"vertical_scroller")
            # Scroller layout
            if [ "$direction" = "left" ] || [ "$direction" = "up" ]; then
                mmsg dispatch "set_proportion,-0.05"
            else
                mmsg dispatch "set_proportion,+0.05"
            fi
            ;;
        *)
            # For other tiling layouts (like master-stack "T" or dwindle "DW"), adjust setmfact
            if [ "$direction" = "left" ] || [ "$direction" = "up" ]; then
                mmsg dispatch "setmfact,-0.05"
            else
                mmsg dispatch "setmfact,+0.05"
            fi
            ;;
    esac
fi

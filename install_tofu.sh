#!/bin/bash

# CloudShell saves the files you have created but not installed packages and software
# so you may need to run this after being inactive on CloudShell

curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
chmod +x install-opentofu.sh
./install-opentofu.sh --install-method standalone --skip-verify
rm install-opentofu.sh

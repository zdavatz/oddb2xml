#!/bin/bash
#
# transfer.sh — push the generated oddb2xml feeds (plus the aips2sqlite
# Fachinformation XML and the swissmedic-sequences CSV) to the HIN download
# server via scp. Runs on the ywesee host; everything is user-owned, so no sudo.
#
# Paths default to this host's layout and can be overridden via environment:
#   ODDB2XML_TRANSFER_DIR  dir whose contents go to .../download/oddb2xml/
#                          (default /home/zdavatz/oddb2xml)
#   AIPS2SQLITE_DIR        aips2sqlite output dir
#                          (default /home/zdavatz/software/aips2sqlite/jars/output)
#   SSH_KEY                scp identity file        (default ~/.ssh/id_ed25519)
#   SCP_DEST               scp destination base, e.g. user@host:/path/download
#                          (REQUIRED — no default yet; set the new download server)

ODDB2XML_TRANSFER_DIR="${ODDB2XML_TRANSFER_DIR:-/home/zdavatz/oddb2xml}"
AIPS2SQLITE_DIR="${AIPS2SQLITE_DIR:-/home/zdavatz/software/aips2sqlite/jars/output}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
# TODO: set the new download-server destination.
SCP_DEST="${SCP_DEST:?set SCP_DEST to the scp target, e.g. user@host:/var/www/.../download}"

###
### ODDB2XML
###

find "$ODDB2XML_TRANSFER_DIR/" -type d -exec chmod 755 {} \;
find "$ODDB2XML_TRANSFER_DIR/" -type f -exec chmod 644 {} \;

scp -r -i "$SSH_KEY" "$ODDB2XML_TRANSFER_DIR"/* "$SCP_DEST/oddb2xml/"

###
### aips2sqlite
###

if [ -d "$AIPS2SQLITE_DIR/fis" ]; then
  find "$AIPS2SQLITE_DIR/fis" -name '*.xml' -type f -exec chmod 644 {} \;
  scp -r -i "$SSH_KEY" "$AIPS2SQLITE_DIR"/fis/*.xml "$SCP_DEST/mediupdate-xml/"
fi

if [ -f "$AIPS2SQLITE_DIR/oddb2xml_swissmedic_sequences.csv" ]; then
  chmod 644 "$AIPS2SQLITE_DIR/oddb2xml_swissmedic_sequences.csv"
  scp -r -i "$SSH_KEY" "$AIPS2SQLITE_DIR/oddb2xml_swissmedic_sequences.csv" "$SCP_DEST/oddb2xml/"
fi

exit 0

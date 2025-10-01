# image_metadata_archives

## installing pre-requisits (mac)
[mac install instructions](./docs/workflow-pre-requisites.md)

## reconciliation
### adjust open refine to display image
[adjust open refine to display image](./docs/open-refine-render-image.md)

### run reconcile service
[reconcile service](./docs/reconciling.md)

## helpful command line commands
list open files listening on relevant ports
    lsof -iTCP -sTCP:LISTEN -P | grep ':8000\|:5000'

curl to them
    curl http://localhost:8000
    curl http://localhost:5000
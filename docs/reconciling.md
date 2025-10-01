# reconciling
## run the reconcile service
https://github.com/cmharlow/lc-reconcile

activate venv
python reconcile.py --debug

## reconcile in open refine

### split multi-value cell

### reconcile column
* Column menu in open-refine > Reconcile > Start Reconcilation
    * Choose the new LoC Reconciliation Service
    * Choose the appropriate reconciliation type

* Adjudicate matches
* Create column based on Reconciled column
    * Transform, column based on this column, `cell.recon.match.name`
* Column menu in open-refine > Edit cells > Join multi-valued cells . . .
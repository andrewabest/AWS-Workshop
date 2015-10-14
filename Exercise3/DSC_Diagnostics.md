# DSC Diagnostics

PowerShell logs all DSC related events to *[Applications and Services Logs/Microsoft/Windows/Desired State Configuration]* in the Windows Event Log.

By default, **analytic** and **debug** level logging are off by default. To turn them on, we can use the [xDscDiagnostics](http://blogs.msdn.com/b/powershell/archive/2014/02/11/dsc-diagnostics-module-analyze-dsc-logs-instantly-now.aspx) module and run the following commands

    Update-xDscEventLogStatus -Channel Analytic -Status Enabled 
    Update-xDscEventLogStatus -Channel Debug -Status Enabled

Once we have enabled our low-level logging, we can query to see what DSC operations have been executed thus far by executing

    Get-xDscOperation

To get detailed information on an operation, we can then go further and use

    Trace-xDscOperation -SequenceID 1 | Format-Table

If you are particularly sadistic, and the xDscDiagnostics tools are not returning the information you want to see, you can query the event log directly using the approaches outlined [here](https://technet.microsoft.com/en-au/library/dn249926.aspx). Disclaimer: it is a horrible way to work.
# Azure-StartStopVm
Tag-Based Start and Stop of VMs

# Supported formats
The following formats are supported.

Format | Example | Meaning
--- | --- | --- 
MM/DD-MM/DD ddd-ddd hh:mm | 12/01 - 12/24  mon-fri 12:00 | Every Monday to Friday within December 1st until December 24th at 12:00
MM/DD-MM/DD ddd-ddd hh:mm | 12/01 - 04/30  fri-mon 12:00 | Every Friday to Monday within December 1st until April 30th at 12:00
MM/DD-MM/DD hh:mm | 12/01 - 12/24 12:00 | From December 1st until December 24th at 12:00
MM/DD ddd-ddd hh:mm | 12/01 mon-fri 12:00 | On December 1st in case it is Monday to Friday at 12:00
MM/DD hh:mm | 12/01 mon-fri 12:00 | On December 1st at 12:00
MM-MM ddd-ddd hh:mm | 12 - 04 mon-wed 12:00 | Every Monday to Wednesday from beginning of Decmeber until the end of April at 12:00
MM-MM hh:mm | 12 - 04 12:00 | From beginning of Decmeber until the end of April at 12:00
MM ddd-ddd hh:mm | 11 tue-thu 12:00 | Every Tuesday to Thursday From beginning of November until the end of November at 12:00
MM hh:mm | 11 12:00 | From beginning of November until the end of November at 12:00
ddd-ddd hh:mm | sat-sun 12:00 | Every Saturday & Sunday to at 12:00
hh:mm | 12:00 | At 12:00


# Evaluation of definitions
More specific dates win - less specific will not be considered in case there is a more specifc one.

Evaluation order is as shown below. In case of a date hit (independent of time hit), lower priorities will not be evaluated.
 1. 12/30 mon 12:00
 1. 12/30 12:00
 1. 12 mon 12:00
 1. 12 12:00
 1. mon 12:00
 1. 12:00


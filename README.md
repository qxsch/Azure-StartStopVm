# Azure-StartStopVm
Tag-Based Start and Stop of VMs

# Supported formats
The following formats are supported.

Format | Example | Meaning
--- | --- | --- 
MM/DD-MM/DD ddd-ddd hh:mm | 12/01 - 12/24  mon-fri 20:00 | Every Monday to Friday within December 1st until December 24th at 20:00
MM/DD-MM/DD ddd-ddd hh:mm | 12/01 - 04/30  fri-mon 20:00 | Every Friday to Monday within December 1st until April 30th at 20:00
MM/DD-MM/DD hh:mm | 12/01 - 12/24 20:00 | From December 1st until December 24th at 20:00
MM/DD ddd-ddd hh:mm | 12/01 mon-fri 20:00 | On December 1st in case it is Monday to Friday at 20:00
MM/DD hh:mm | 12/01 mon-fri 20:00 | On December 1st at 20:00
MM-MM ddd-ddd hh:mm | 12 - 04 mon-wed 20:00 | Every Monday to Wednesday from beginning of Decmeber until the end of April at 20:00
MM-MM hh:mm | 12 - 04 20:00 | From beginning of Decmeber until the end of April at 20:00
MM ddd-ddd hh:mm | 11 tue-thu 20:00 | Every Tuesday to Thursday From beginning of November until the end of November at 20:00
MM hh:mm | 11 20:00 | From beginning of November until the end of November at 20:00
ddd-ddd hh:mm | sat-sun 20:00 | Every Saturday & Sunday to at 20:00
hh:mm | 20:00 | At 20:00


# Evaluation of definitions
You can add multiple definitions in one line seperated by a ```;```

More specific dates win - less specific will not be considered in case there is a more specifc one.

Evaluation order is as shown below. In case of a date hit (independent of time hit), lower priorities will not be evaluated. However, all entries in the same priority bucket will always be evaluated.
 1. 12/30 mon 20:00
 1. 12/30 20:00
 1. 12 mon 20:00
 1. 12 20:00
 1. mon 20:00
 1. 20:00


**Example:**  ```mon-fri 20:00 ; sat-sun 16:00; 12/01 - 01/31 mon-fri 22:00; 12/01 - 01/31 sat-sun 21:00```
Result: 
 - Monday to Friday at 20:00     (Will just be evaluated from February 1st until November 30th)
 - Saturday and Sunday at 16:00  (Will just be evaluated from February 1st until November 30th)
 - Monday to Friday from December 1st until January 31st at 22:00
 - Saturday and Sunday from December 1st until January 31st at 21:00


**Please be aware**
 - The following rule will trigger on a daily basis with highest (1st) priority ```01/01 - 12/31  mon-sun  20:00``` and "disable" lower priorities 2 - 6.
 - The following rule will trigger on a daily basis with 2nd priority ```01/01 - 12/31   20:00``` and "disable" lower priorities 3 - 6. (In case priority 2 gets evaluated.)
 - The following rule will trigger on a daily basis with 3rd priority ```01 - 12  mon-sun 20:00``` and "disable" lower priorities 4 - 6. (In case priority 3 gets evaluated.)
 - The following rule will trigger on a daily basis with 4th priority ```01 - 12  20:00``` and "disable" lower priorities 5 - 6. (In case priority 4 gets evaluated.)
 - The following rule will trigger on a daily basis with 5th priority ```mon-sun  20:00``` and "disable" lower priority 6. (In case priority 5 gets evaluated.)

 

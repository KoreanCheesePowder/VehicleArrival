C.P Vehicle Arrival Edge Driver v1.3.6

Routine trigger redesign:
- Uses STANDARD SmartThings switch capability.
- Separate component: 입차 감지
- Separate component: 출차 감지
- IN  : 입차 감지 OFF -> ON immediately -> 30 sec -> OFF
- OUT : 출차 감지 OFF -> ON immediately -> 30 sec -> OFF
- Repeated IN/IN and OUT/OUT are never ignored.
- Detail view remains vehicle plate/time + driver information.

Routine condition:
- 입차 감지 / 스위치 / 켜짐
- 출차 감지 / 스위치 / 켜짐

packageKey:
- cp-vehicle-arrival

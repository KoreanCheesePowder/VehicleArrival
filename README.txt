C.P Vehicle Arrival Edge Driver v1.3.6

NAS에서 전달되는 차량 입·출차 이벤트를 SmartThings에 표시하고 자동화 트리거로 제공하는 LAN Edge 드라이버입니다.

주요 기능
- Wallpad-LanLogger NAS의 TCP 이벤트 포트에 연결하고 연결이 끊기면 5초 후 재연결
- 가족 차량번호 목록을 CONFIG| 형식으로 NAS에 동기화
- 입차·출차 차량번호와 이벤트 시간 표시
- 입차 시 entryTrigger, 출차 시 exitTrigger의 표준 switch를 OFF -> ON으로 즉시 전환한 뒤 30초 후 OFF
- 같은 방향의 이벤트가 연속 발생해도 IN/IN, OUT/OUT을 각각 독립적으로 처리
- refresh 실행 또는 설정 변경 시 NAS 연결과 가족 차량번호 설정을 다시 동기화
- 드라이버 정보에 제작자와 버전 표시

자동화 조건
- 입차 감지 / 스위치 / 켜짐
- 출차 감지 / 스위치 / 켜짐

설정
- NAS IP: Wallpad-LanLogger가 실행되는 NAS의 내부 IP
- NAS 이벤트 포트: 기본값 19093
- 가족 차량번호: 여러 대는 쉼표로 구분

설치
1. SmartThings CLI를 설치하고 로그인합니다.
2. SETUP-AND-INSTALL.cmd를 실행합니다.
3. SmartThings 앱에서 기기 추가 -> 주변 검색을 실행합니다.

드라이버 정보
- 제작자: 치즈가루
- 버전: v1.3.6
- packageKey: cp-vehicle-arrival

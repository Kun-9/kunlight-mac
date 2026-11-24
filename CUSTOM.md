# 개인 수정본

새 화면과 모양은 별도 파일이고, 원본 파일은 연결만 몇 줄 고쳤다. 원본을 받을 때 충돌이 나면 아래만 보면 된다.

새 파일
- `app/gui/Theme.qml`: 모든 색. 색은 여기서만 바꾼다.
- `app/gui/HomeView.qml`: 첫 화면. 위에 PC 알약, 아래에 고른 PC 게임. Ctrl+D 는 Desktop 바로 접속.
- `app/gui/GameCarousel.qml`: 게임 표지 가로 넘기기. 실행 중인 게임이 있으면 다른 게임을 골라도 그 게임으로 이어 한다.
- `app/gui/SettingsShell.qml`: 왼쪽 분류 설정. 원본 `SettingsView.qml` 을 숨겨 불러와 칸 묶음(GroupBox)만 옮겨 온다. 원본에 새 설정이 생기면 그대로 따라온다.
- `app/streaming/video/statspanel.h/.cpp`: 스트리밍 통계(Ctrl+Option+Shift+S)를 카드·한 줄 띠로 그림. 모양은 설정 > 통계(`statsStyle` 키).
- `app/gui/mactitlebar.h/.mm`: 맥 창에 빈 툴바를 붙여 제목줄을 약 52px로 넓힘(신호등이 맨 위 줄 가운데로)
- `app/res/custom/`, `app/res/fonts/`: 선 아이콘, Pretendard(SIL OFL)
- `app/MoonStyle/`: Material 을 덮어쓰는 컨트롤 모양(스위치·카드·선택 칸·단추·확인 창·입력 칸). 없는 컨트롤은 Material 그대로.

원본에서 고친 곳
- `app/main.cpp`: 첫 화면 `HomeView.qml`, 스타일 `MoonStyle`, `engine.addImportPath("qrc:/")`, Theme 등록 한 줄
- `app/qml.qrc`: 새 파일 목록
- `app/app.pro`: mactitlebar 두 줄(macx)
- `app/main.cpp`: MacTitlebar::apply 한 줄과 include
- `app/gui/main.qml`: Theme 색, 디스코드·도움말 단추 `visible: false`, PC 추가 단추를 HomeView 에서도, 설정 단추가 SettingsShell 로
- `app/gui/SettingsView.qml`: `import Theme 1.0`, 칸 제목 색(skyblue -> Theme.accent) 7줄
- `app/gui/StreamSegue.qml`: 접속 중 화면(흐린 표지 배경, 가운데 작은 표지, 작은 안내), `boxart` 속성
- `app/backend/computermanager.cpp`, `app/gui/computermodel.*`: PC 순서 바꾸기(`pcOrder` 설정, getComputers 정렬)
- 위 막대는 화면의 `ownsTopBar` 속성으로 숨김(HomeView, StreamSegue)
- `app/gui/NavigableMessageDialog.qml`: 아이콘 50 -> 26, 크기 고정(창 폭이 늦게 잡혀 글자가 넘치던 것)
- `app/gui/appmodel.h/.cpp`: `getRunningAppIndex()`, `getDesktopAppIndex()` 추가
- `app/streaming/video/overlaymanager.cpp`: 통계 그림을 StatsPanel 로 고르는 한 줄
- `app/streaming/video/ffmpeg.cpp`: StatsPanel 에 값을 넘기는 한 줄
- `app/app.pro`: statspanel 파일 두 줄
- `app/streaming/input/keyboard.cpp`: 오른쪽 Alt 를 한/영(VK_HANGUL 0x15)으로 보냄
- `app/backend/nvapp.*`, `app/backend/nvcomputer.cpp`, `app/gui/appmodel.*`, `app/gui/AppView.qml`: 게임 순서 옮기기(내 기기에만 저장)

원본 받기: `git fetch upstream && git merge upstream/master && git submodule update --init --recursive && python3 setup-deps.py`

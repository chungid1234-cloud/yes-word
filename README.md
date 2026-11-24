# YES WORD v0.3
한국어 말씀 암송용 모바일 PWA. 독립적인 개인 학습 프로토타입이며 교회의 공식 서비스가 아닙니다.

## GitHub Pages 배포
1. GitHub에서 `yes-word` 저장소를 생성합니다. 무료 GitHub Pages를 사용하려면 공개 저장소를 선택합니다. 이 소스에는 개인 말씀이나 녹음이 포함되지 않습니다.
2. ZIP을 압축 해제하고 이 폴더 안의 파일들을 저장소 루트에 업로드하여 main 브랜치에 commit합니다.
3. Settings > Pages > Build and deployment > Deploy from a branch > main / (root) > Save.
4. Pages 설정에 표시된 HTTPS URL을 모바일 Chrome 또는 Safari에서 엽니다. Android: 메뉴 > 홈 화면에 추가 / 앱 설치. iPhone: Safari 공유 > 홈 화면에 추가.

## 로컬 실행
`python -m http.server 8000` 실행 후 `http://localhost:8000`을 엽니다. 빌드나 npm 설치가 필요 없습니다. 녹음은 HTTPS 또는 localhost가 필요합니다.

## 구현 범위
- 새일꾼반 13과, 15개 주소 템플릿 (본문 미포함)
- 개인 플랜, 본문 수정, 일괄 등록, 즐겨찾기, 묵상 노트, 수정 이력 저장, 삭제 복구, JSON 백업
- 8개 훈련 모드 및 자기 평가, 문자 편집거리 기반 채점, 복습 일정, 학습 통계, 배지
- 브라우저 TTS 음성 선택, 속도, 반복, 휴식, 재생 범위, 타이머
- MediaRecorder / IndexedDB 개인 녹음, 재생, 다운로드, 삭제
- 라이트/다크/시스템 테마, PWA manifest 및 기본 오프라인 캐시

## 제한 및 다음 단계
- 아직 회원가입, 서버 DB, 그룹, 리더, 제출, 클라우드 동기화, 자동 음성 채점, 푸시 알림, 영어 UI는 구현되지 않았습니다.
- TTS 음성과 잠금 화면 재생은 기기별로 다릅니다. 실제 Android/iOS 테스트가 필요합니다.
- 브라우저 데이터 삭제 시 로컬 학습 기록이 삭제될 수 있습니다. JSON 백업과 녹음 다운로드를 사용하세요.
- 공개 배포 전 교회 명칭 사용 허가 및 본문 이용 권한을 확인하세요. 개인 입력 본문은 배포 코드에 포함하지 않습니다.
- JavaScript 구문 검사 완료. 테스트 환경의 브라우저 탐색 제한으로 전체 브라우저 통합 테스트는 미완료입니다.


## v0.3
- Local first-run profile onboarding (name and affiliation), personalized home, editable profile.
- Existing local storage keys preserved; profile is not an authenticated account.
- Next backend milestone: configure Supabase Auth, owner-only data policies, and explicitly confirmed migration of existing local data.

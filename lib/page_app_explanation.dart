// page_app_explanation.dart
import 'package:flutter/material.dart';

class PageAppExplanation extends StatelessWidget {
  const PageAppExplanation({Key? key}) : super(key: key);

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bodyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용 설명'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              _sectionTitle('1. 앱 소개'),

              _bodyText(
                '우리아이 성장 그래프는 아이의 키, 몸무게, BMI(체질량지수)를 '
                '국가 표준 성장곡선과 함께 비교하여 한눈에 확인할 수 있도록 만든 앱입니다.'
              ),

              _bodyText(
                '단순 기록이 아니라, 아이의 성장 흐름을 시간에 따라 시각적으로 '
                '확인하는 것이 목적입니다.'
              ),

              _sectionTitle('2. 기본 사용 방법'),

              _bodyText(
                '① 프로필 등록\n'
                '하단의 “프로필” 버튼을 눌러 아이의 이름, 성별, 생년월일을 등록합니다.'
              ),

              _bodyText(
                '② 성장 데이터 입력\n'
                '아이를 선택한 뒤 “성장 데이터 입력”을 누르면 해당 날짜의 키와 몸무게를 입력할 수 있습니다.\n\n'
                '키 또는 몸무게 중 하나만 입력해도 저장이 가능합니다.\n'
                'BMI는 키와 몸무게가 모두 있을 때 자동 계산됩니다.'
              ),

              _bodyText(
                '③ 그래프 보기\n'
                '“그래프 보기”를 누르면 표준 성장곡선과 아이의 데이터를 함께 확인할 수 있습니다.\n'
                '그래프를 터치하면 확대/이동이 가능하며, 중심 좌표도 확인할 수 있습니다.'
              ),

              _sectionTitle('3. 데이터 저장 방식 (중요 안내)'),

              _bodyText(
                '이 앱은 기본적으로 사용자의 데이터를 외부 서버로 전송하지 않습니다.\n'
                '입력한 모든 성장 데이터는 사용자의 휴대폰 내부에 안전하게 저장됩니다.'
              ),

              _bodyText(
                '즉, 아이의 키·몸무게 정보는 외부로 공유되지 않으며, '
                '오직 사용자의 기기 안에만 보관됩니다.'
              ),

              _bodyText(
                '앱을 삭제하면 기기 내부 데이터도 함께 삭제될 수 있으므로, '
                '중요한 데이터는 반드시 “백업 내보내기” 기능을 이용해 파일로 저장해두시기 바랍니다.'
              ),

              _sectionTitle('4. 백업 / 복원 기능'),

              _bodyText(
                '상단의 업로드(↑) 아이콘을 누르면 현재 데이터를 .json 파일로 저장할 수 있습니다.\n'
                '이 파일은 휴대폰 저장공간, 클라우드, 메신저 등을 통해 보관할 수 있습니다.'
              ),

              _bodyText(
                '다운로드(↓) 아이콘을 누르면 이전에 저장해둔 백업 파일을 다시 불러올 수 있습니다.\n'
                '기기를 바꾸더라도 백업 파일이 있다면 데이터를 복원할 수 있습니다.'
              ),

              _sectionTitle('5. 보상 광고 안내'),

              _bodyText(
                '무료 버전에서는 일부 기능(예: 백업 기능 사용 시)에 '
                '보상형 광고가 표시될 수 있습니다.'
              ),

              _bodyText(
                '보상 광고는 일정 시간의 광고를 시청한 뒤 기능이 활성화되는 방식입니다.\n'
                '이는 앱 운영을 유지하기 위한 최소한의 장치이며, '
                '사용자의 데이터를 수집하기 위한 목적이 아닙니다.'
              ),

              _bodyText(
                '광고 시청은 선택 사항이며, '
                '광고 없이 모든 기능을 사용하고 싶으신 경우 유료 구독을 통해 '
                '광고 제거 및 기능 제한 해제가 가능합니다.'
              ),

              _sectionTitle('6. 무료 / 유료 버전 차이'),

              _bodyText(
                '무료 버전\n'
                '• 최대 2명의 자녀 프로필 등록 가능\n'
                '• 일부 기능 사용 시 보상 광고 표시\n'
                '• 데이터는 기기 내부에 저장'
              ),

              _bodyText(
                '유료 버전 (월 구독)\n'
                '• 프로필 등록 제한 없음\n'
                '• 광고 없음\n'
                '• 향후 클라우드 저장 기능 지원 예정'
              ),

              _sectionTitle('7. 개인정보 및 안전성'),

              _bodyText(
                '이 앱은 아이의 건강 데이터를 소중하게 생각합니다.\n'
                '기본적으로 서버 전송 없이 로컬 저장을 원칙으로 합니다.'
              ),

              _bodyText(
                '사용자의 동의 없이 개인 데이터를 외부로 전송하지 않습니다.'
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

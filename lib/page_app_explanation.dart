// page_explanation.dart
import 'package:flutter/material.dart';

class PageAppExplanation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '📌 앱 사용 설명',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('1. 자녀 정보를 입력하여 성장 데이터를 기록하세요.'),
              Text('2. 키, 몸무게, BMI 등 표준 성장 곡선에 따라 시각화됩니다.'),
              Text('3. 무료는 2명까지 입력 가능하며 로컬에 저장됩니다.'),
              Text('4. 유료 구독 시 광고 없이 클라우드 저장이 가능합니다.'),
              Text('5. 하단 탭을 눌러 각 기능으로 이동할 수 있습니다.'),
            ],
          ),
        ),
      ),
    );
  }
}

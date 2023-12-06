# StockTrading

이 Solidity 스마트 컨트랙트는 주식 거래 플랫폼을 구현한 것입니다. 

주식을 발행하고 거래하기 위한 여러 기능을 포함하고 있습니다.


## 구조 및 주요 기능

### Contract 구조

- **PrivateEquity Struct**: IPO 및 투표 관련 정보를 저장합니다.
- **Stock Struct**: 주식에 대한 정보를 저장하는 구조체.
- **Order Struct**: 거래 주문에 대한 정보를 저장합니다.
- **Step Struct**: 거래 가격 단계와 관련된 정보를 저장합니다.

### 기능

1. **IPO 및 투표**
    - `listingPrivateEquity`:IPO를 등록합니다.
    - `voteIPO`: IPO에 투표합니다.
    - `passedIPO`: IPO에 성공하면 투표자들에게 주식을 분배합니다.

2. **주문 및 거래**
    - `placeBuyOrder`: 주식 매수 주문을 등록하고 거래합니다.
    - `placeSellOrder`: 주식 매도 주문을 등록하고 거래합니다.

3. **가격 단계 및 주문 정렬**
    - `_alignBuyOrder` 및 `_alignSellOrder`: 체결된 주문을 삭제하고 정렬합니다.
    - `_drawToBuyBook` 및 `_drawToSellBook`: 주문을 거래북에 등록하고 관련된 가격 단계를 업데이트합니다.

4. **보조 함수**
    - `hasVoted`: 특정 주소가 투표했는지 확인합니다.

## 참고 사항

- 이 컨트랙트는 주식 거래 시스템의 핵심 기능만을 포함하고 있으며, 보안 측면과 실제 환경에서의 사용을 위해서 추가 개선이 필요할 수 있습니다.

# StockTrading

주식 시장 컨트랙트 개발중


주식을 만들 수 있고 사람들의 투표를 통해 상장을 결정

상장되면 비율에 따라 주식이 배분되고 매수, 매도 가능

수정예정
- highestBuyPrice, lowestSellPrice 변경

  struct Step{
    uint highestBuyPrice;
    uint currentPrice;
    uint lowestSellPrice;
  }

추가예정
- 현재가보다 높거나 낮은 매수, 매도 시 밑의 가격으로 채결

#!/bin/bash

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="petclinic"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}펫클리닉 EKS 모니터링${NC}"
echo -e "${BLUE}========================================${NC}\n"

# 함수: Pod 상태 확인
check_pods() {
    echo -e "${YELLOW}[Pod 상태]${NC}"
    kubectl get pods -n $NAMESPACE -o wide
    
    echo -e "\n${YELLOW}[Pod 상세 정보]${NC}"
    POD_NAME=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$POD_NAME" ]; then
        echo "Pod: $POD_NAME"
        kubectl describe pod $POD_NAME -n $NAMESPACE
    fi
}

# 함수: 서비스 상태 확인
check_services() {
    echo -e "\n${YELLOW}[Service 상태]${NC}"
    kubectl get svc -n $NAMESPACE
    
    echo -e "\n${YELLOW}[LoadBalancer 상태]${NC}"
    EXTERNAL_IP=$(kubectl get svc petclinic-lb -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "${GREEN}외부 IP: $EXTERNAL_IP${NC}"
        echo -e "${GREEN}접속 URL: http://$EXTERNAL_IP/petclinic${NC}"
    else
        echo -e "${YELLOW}외부 IP 할당 대기 중...${NC}"
    fi
}

# 함수: 로그 확인
check_logs() {
    echo -e "\n${YELLOW}[애플리케이션 로그]${NC}"
    POD_NAME=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$POD_NAME" ]; then
        echo "최근 로그 (Pod: $POD_NAME):"
        kubectl logs $POD_NAME -n $NAMESPACE --tail=50
    fi
}

# 함수: 데이터베이스 연결 확인
check_db_connection() {
    echo -e "\n${YELLOW}[데이터베이스 연결 상태]${NC}"
    POD_NAME=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
    if [ -n "$POD_NAME" ]; then
        echo "Pod 내에서 RDS 연결 테스트..."
        kubectl exec -it $POD_NAME -n $NAMESPACE -- bash -c \
            'curl -s http://localhost:8080/petclinic 2>&1 | head -20'
    fi
}

# 함수: 리소스 사용량 확인
check_resources() {
    echo -e "\n${YELLOW}[리소스 사용량]${NC}"
    kubectl top pods -n $NAMESPACE --no-headers 2>/dev/null || echo "Metrics 서버 미설치"
    
    echo -e "\n${YELLOW}[Node 리소스]${NC}"
    kubectl top nodes --no-headers 2>/dev/null || echo "Metrics 서버 미설치"
}

# 함수: 배포 히스토리 확인
check_rollout() {
    echo -e "\n${YELLOW}[배포 히스토리]${NC}"
    kubectl rollout history deployment/petclinic -n $NAMESPACE
}

# 함수: 이벤트 확인
check_events() {
    echo -e "\n${YELLOW}[최근 이벤트]${NC}"
    kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20
}

# 메인 메뉴
while true; do
    echo -e "\n${BLUE}모니터링 메뉴:${NC}"
    echo "1) Pod 상태 확인"
    echo "2) Service 상태 확인"
    echo "3) 애플리케이션 로그"
    echo "4) 데이터베이스 연결 테스트"
    echo "5) 리소스 사용량"
    echo "6) 배포 히스토리"
    echo "7) 최근 이벤트"
    echo "8) 전체 확인"
    echo "9) 종료"
    echo -n "선택: "
    read choice
    
    case $choice in
        1) check_pods ;;
        2) check_services ;;
        3) check_logs ;;
        4) check_db_connection ;;
        5) check_resources ;;
        6) check_rollout ;;
        7) check_events ;;
        8) 
            check_pods
            check_services
            check_logs
            check_resources
            check_events
            ;;
        9) 
            echo -e "${BLUE}종료합니다${NC}"
            break
            ;;
        *)
            echo -e "${RED}잘못된 선택입니다${NC}"
            ;;
    esac
done
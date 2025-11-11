



echo -e "\n${YELLOW}[Step 5] Deployment YAML 업데이트${NC}"
sed -i "s|<AWS_ACCOUNT_ID>\.dkr\.ecr\..*\.amazonaws\.com/petclinic:latest|$IMAGE_URI|g" petclinic-deployment.yaml
echo -e "${GREEN}YAML 파일 업데이트 완료${NC}"


echo -e "\n${YELLOW}[Step 6] Kubernetes Secret 생성${NC}"
read -sp "RDS MySQL 비밀번호 입력: " DB_PASSWORD
echo ""

kubectl create secret generic petclinic-db-secret \
    --from-literal=DB_PASSWORD="$DB_PASSWORD" \
    -n petclinic --dry-run=client -o yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Secret 생성 완료${NC}"
else
    echo -e "${YELLOW}Secret 생성 실패${NC}"
fi

echo -e "\n${YELLOW}[Step 7] EKS 클러스터에 배포${NC}"
kubectl apply -f petclinic-deployment.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}배포 완료${NC}"
else
    echo -e "${YELLOW}배포 실패${NC}"
    exit 1
fi

echo -e "\n${YELLOW}[Step 8] 배포 상태 확인${NC}"
echo "deployment 상태:"
kubectl get deployment -n petclinic

echo -e "\npod 상태:"
kubectl get pods -n petclinic

echo -e "\nLoadBalancer 서비스:"
kubectl get svc -n petclinic


echo -e "\n${YELLOW}LoadBalancer 외부 IP 획득 중 (최대 3분 대기)...${NC}"
for i in {1..36}; do
    EXTERNAL_IP=$(kubectl get svc petclinic-lb -n petclinic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "${GREEN}외부 IP 획득 완료: $EXTERNAL_IP${NC}"
        echo -e "${GREEN}펫클리닉 접속: http://$EXTERNAL_IP/petclinic${NC}"
        break
    fi
    echo "대기 중... ($((i*5))초)"
    sleep 5
done

if [ -z "$EXTERNAL_IP" ]; then
    echo -e "${YELLOW}외부 IP 획득 실패 (시간 초과)${NC}"
    echo "다음 명령어로 나중에 확인할 수 있습니다:"
    echo "kubectl get svc petclinic-lb -n petclinic"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}배포 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
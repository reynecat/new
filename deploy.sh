# deploy.sh
read -p "ECR 이미지 URI 입력 (예: ACCOUNT_ID.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic:latest): " IMAGE_URI

echo -e "\n${YELLOW} Deployment YAML 업데이트${NC}"
sed -i "s|<AWS_ACCOUNT_ID>\.dkr\.ecr\..*\.amazonaws\.com/petclinic:latest|$IMAGE_URI|g" petclinic-deployment.yaml
echo -e "${GREEN}YAML 파일 업데이트 완료${NC}"


echo -e "\n${YELLOW}Kubernetes Secret 생성${NC}"
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

echo -e "\n${YELLOW} EKS 클러스터에 배포${NC}"
kubectl apply -f petclinic-deployment.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}배포 완료${NC}"
else
    echo -e "${YELLOW}배포 실패${NC}"
    exit 1
fi

echo -e "\n${YELLOW} 배포 상태 확인${NC}"
echo "deployment 상태:"
kubectl get deployment -n petclinic

echo -e "\npod 상태:"
kubectl get pods -n petclinic

echo -e "\nLoadBalancer 서비스:"
kubectl get svc -n petclinic

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}배포 완료!${NC}"
echo -e "${GREEN}========================================${NC}"
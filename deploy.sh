#!/bin/bash

# 설정
AWS_REGION="ap-northeast-2"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_NAME="petclinic"
IMAGE_TAG="latest"
IMAGE_URI="${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}펫클리닉 EKS 배포 자동화${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Step 1: ECR 리포지토리 확인 및 생성
echo -e "${YELLOW}[Step 1] ECR 리포지토리 확인${NC}"
if ! aws ecr describe-repositories --repository-names $IMAGE_NAME --region $AWS_REGION 2>/dev/null; then
    echo "ECR 리포지토리 생성 중..."
    aws ecr create-repository \
        --repository-name $IMAGE_NAME \
        --region $AWS_REGION \
        --encryption-configuration encryptionType=AES \
        --image-scanning-configuration scanOnPush=true
    echo -e "${GREEN}ECR 리포지토리 생성 완료${NC}"
else
    echo -e "${GREEN}ECR 리포지토리 이미 존재${NC}"
fi

# Step 2: ECR 로그인
echo -e "\n${YELLOW}[Step 2] ECR 로그인${NC}"
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $ECR_REGISTRY
echo -e "${GREEN}ECR 로그인 완료${NC}"

# Step 3: Docker 이미지 빌드
echo -e "\n${YELLOW}[Step 3] Docker 이미지 빌드${NC}"
docker build -f Dockerfile.springboot -t $IMAGE_URI .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}이미지 빌드 완료: $IMAGE_URI${NC}"
else
    echo -e "${YELLOW}이미지 빌드 실패${NC}"
    exit 1
fi

# Step 4: ECR에 푸시
echo -e "\n${YELLOW}[Step 4] ECR에 이미지 푸시${NC}"
docker push $IMAGE_URI
if [ $? -eq 0 ]; then
    echo -e "${GREEN}ECR 푸시 완료${NC}"
else
    echo -e "${YELLOW}ECR 푸시 실패${NC}"
    exit 1
fi

# Step 5: Deployment YAML 업데이트
echo -e "\n${YELLOW}[Step 5] Deployment YAML 업데이트${NC}"
sed -i "s|<AWS_ACCOUNT_ID>\.dkr\.ecr\..*\.amazonaws\.com/petclinic:latest|$IMAGE_URI|g" petclinic-deployment.yaml
echo -e "${GREEN}YAML 파일 업데이트 완료${NC}"

# Step 6: RDS 비밀번호 입력 및 Secret 생성
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

# Step 7: EKS에 배포
echo -e "\n${YELLOW}[Step 7] EKS 클러스터에 배포${NC}"
kubectl apply -f petclinic-deployment.yaml

if [ $? -eq 0 ]; then
    echo -e "${GREEN}배포 완료${NC}"
else
    echo -e "${YELLOW}배포 실패${NC}"
    exit 1
fi

# Step 8: 배포 상태 확인
echo -e "\n${YELLOW}[Step 8] 배포 상태 확인${NC}"
echo "deployment 상태:"
kubectl get deployment -n petclinic

echo -e "\npod 상태:"
kubectl get pods -n petclinic

echo -e "\nLoadBalancer 서비스:"
kubectl get svc -n petclinic

# LoadBalancer 외부 IP 대기
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
# 펫클리닉 EKS 배포 가이드

## 📋 목표
Spring Boot 펫클리닉 애플리케이션을 AWS RDS MySQL과 연동하여 EKS에 배포하고 LoadBalancer Service로 외부 접속 가능하게 구성

## 🏗️ 아키텍처 개요

```
사용자 
  ↓
[Internet] 
  ↓
ALB/NLB (Public Subnet)
  ↓
EKS LoadBalancer Service (포트 80)
  ↓
Spring Boot Pod (Private nodegrp Subnet)
  ↓ (JDBC)
RDS MySQL (Private RDS Subnet)
```

### 서브넷 구성
- **Public Subnet**: 10.0.0.0/24, 10.0.10.0/24 (ALB)
- **Private EKS Management**: 10.0.20.0/24, 10.0.30.0/24
- **Private Worker Nodes**: 10.0.40.0/24, 10.0.50.0/24 (Pod 실행)
- **Private RDS**: 10.0.60.0/24, 10.0.70.0/24 (MySQL 연동)

---

## 📦 파일 구조

```
/home/claude/
├── Dockerfile.springboot           # Spring Boot 이미지 빌드
├── pom-mysql-profile.xml           # Maven MySQL 프로필 설정
├── petclinic-deployment.yaml       # EKS Deployment + Service
├── deploy.sh                        # 배포 자동화 스크립트
├── monitor.sh                       # 모니터링 스크립트
└── DEPLOY_GUIDE.md                 # 이 파일
```

---

## 🚀 배포 단계별 실행

### 사전 준비
1. **AWS CLI 설정 완료**
   ```bash
   aws configure --profile default
   aws sts get-caller-identity  # 확인
   ```

2. **kubectl 설정 완료**
   ```bash
   aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2
   kubectl get nodes  # 클러스터 연결 확인
   ```

3. **Docker 설치 확인**
   ```bash
   docker --version
   docker ps
   ```

### Step 1: 자동 배포 실행
```bash
cd /home/claude

# 배포 스크립트 실행
./deploy.sh
```

**스크립트가 수행하는 작업:**
- ECR 리포지토리 생성 (또는 기존 확인)
- Docker 이미지 빌드 (MySQL 프로필)
- ECR에 이미지 푸시
- Kubernetes Namespace 생성
- ConfigMap 생성 (DB 정보)
- Secret 생성 (DB 비밀번호)
- Deployment 배포
- LoadBalancer Service 생성
- 외부 IP 할당 대기

### Step 2: 배포 상태 확인
```bash
# Deployment 상태
kubectl get deployment -n petclinic

# Pod 실행 상태
kubectl get pods -n petclinic -w

# Service 및 LoadBalancer
kubectl get svc -n petclinic
```

### Step 3: 외부 IP 확인 및 접속
```bash
# LoadBalancer 외부 IP 확인
kubectl get svc petclinic-lb -n petclinic

# 예상 출력:
# NAME           TYPE           CLUSTER-IP      EXTERNAL-IP                                  PORT(S)        
# petclinic-lb   LoadBalancer   10.x.x.x        *.elb.ap-northeast-2.amazonaws.com          80:31234/TCP

# 브라우저에서 접속
# http://<EXTERNAL-IP>/petclinic
```

---

## 🔧 자세한 설정 정보

### 1. Dockerfile 설명
**파일**: `Dockerfile.springboot`
- **Build Stage**: Maven으로 MySQL 프로필을 사용해 WAR 컴파일
- **Runtime Stage**: Tomcat 11 기반 이미지
- **특징**:
  - Multi-stage 빌드로 최종 이미지 크기 최소화
  - 헬스체크 설정 (EKS 자동 복구)
  - RDS MySQL 자동 연동

### 2. Deployment 설정 상세

#### ConfigMap (데이터베이스 정보)
```yaml
DB_HOST: db-amazonvet.ciyiccb2k2z8.ap-northeast-2.rds.amazonaws.com
DB_PORT: 3306
DB_NAME: petclinic
DB_USER: admin
```

#### Secret (보안)
```bash
# 수동 생성 방법
kubectl create secret generic petclinic-db-secret \
  --from-literal=DB_PASSWORD='YOUR_PASSWORD' \
  -n petclinic
```

#### Deployment 설정
- **Replicas**: 2개 (고가용성)
- **Pod Anti-Affinity**: 다른 노드에 배치
- **Resource Limits**: 
  - 요청: CPU 250m, Memory 256Mi
  - 한계: CPU 500m, Memory 512Mi
- **Liveness Probe**: 30초 간격 헬스체크
- **Readiness Probe**: 5초 간격 준비 상태 확인

#### Service (LoadBalancer)
- **Type**: LoadBalancer (AWS ALB/NLB)
- **Port Mapping**: 80 (외부) → 8080 (Pod)
- **Session Affinity**: ClientIP (세션 유지)
- **외부 접근**: Public Subnet의 ALB/NLB를 통해 제공

---

## 📊 모니터링 및 관리

### 자동 모니터링 스크립트
```bash
./monitor.sh
```

메뉴 옵션:
1. Pod 상태 확인
2. Service 상태 확인
3. 애플리케이션 로그
4. 데이터베이스 연결 테스트
5. 리소스 사용량
6. 배포 히스토리
7. 최근 이벤트
8. 전체 확인

### 수동 명령어

**Pod 로그 확인**
```bash
POD_NAME=$(kubectl get pods -n petclinic -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME -n petclinic --tail=100 -f
```

**Pod에 접속**
```bash
kubectl exec -it $POD_NAME -n petclinic -- bash
```

**이벤트 확인**
```bash
kubectl get events -n petclinic --sort-by='.lastTimestamp'
```

**배포 상태**
```bash
kubectl rollout status deployment/petclinic -n petclinic
```

---

## ⚠️ 트러블슈팅

### 1. Pod가 Pending 상태
**원인**: 리소스 부족 또는 노드 이슈

```bash
# 상세 확인
kubectl describe pod <POD_NAME> -n petclinic

# 노드 상태 확인
kubectl get nodes
kubectl top nodes
```

### 2. CrashLoopBackOff 상태
**원인**: 애플리케이션 시작 실패 (보통 DB 연결 문제)

```bash
# 로그 확인
kubectl logs <POD_NAME> -n petclinic

# 일반적인 원인:
# - DB_PASSWORD 환경변수 누락
# - RDS 보안 그룹 설정 오류
# - MySQL 엔드포인트 오류
```

### 3. LoadBalancer 외부 IP 미할당
**원인**: AWS 리소스 부족 또는 권한 문제

```bash
# 서비스 상태 확인
kubectl describe svc petclinic-lb -n petclinic

# 이벤트 확인
kubectl get events -n petclinic
```

### 4. RDS 연결 실패

**RDS 보안 그룹 확인**
```bash
# RDS 보안 그룹이 다음을 허용해야 함:
# - Source: Worker Node 보안 그룹
# - Port: 3306
# - Protocol: TCP
```

**데이터베이스 생성 확인**
```bash
# RDS에서 실행:
CREATE DATABASE IF NOT EXISTS petclinic CHARACTER SET utf8mb4;
```

---

## 🔄 배포 업데이트

### 이미지 업데이트
```bash
# 1. 새 이미지 빌드 및 ECR 푸시
docker build -f Dockerfile.springboot -t <IMAGE_URI> .
docker push <IMAGE_URI>

# 2. Deployment 이미지 업데이트
kubectl set image deployment/petclinic \
  petclinic=<NEW_IMAGE_URI> \
  -n petclinic

# 3. 배포 롤링 업데이트 상태 확인
kubectl rollout status deployment/petclinic -n petclinic

# 4. 이전 버전으로 롤백 (필요시)
kubectl rollout undo deployment/petclinic -n petclinic
```

### 설정 변경
```bash
# ConfigMap 수정
kubectl edit configmap petclinic-config -n petclinic

# Secret 업데이트
kubectl delete secret petclinic-db-secret -n petclinic
kubectl create secret generic petclinic-db-secret \
  --from-literal=DB_PASSWORD='NEW_PASSWORD' \
  -n petclinic

# Pod 자동 재시작 (ConfigMap/Secret 변경 후)
kubectl rollout restart deployment/petclinic -n petclinic
```

---

## 🧹 정리 및 삭제

### 모든 리소스 삭제
```bash
# Deployment, Service, ConfigMap, Secret 모두 삭제
kubectl delete namespace petclinic

# 또는 선택적 삭제
kubectl delete deployment petclinic -n petclinic
kubectl delete svc petclinic-lb -n petclinic
kubectl delete configmap petclinic-config -n petclinic
kubectl delete secret petclinic-db-secret -n petclinic
```

### ECR 이미지 정리
```bash
# ECR 이미지 삭제
aws ecr delete-repository \
  --repository-name petclinic \
  --force \
  --region ap-northeast-2
```

---

## 📝 환경변수 정보

### pom.xml MySQL 프로필
```xml
<jdbc.url>jdbc:mysql://db-amazonvet.ciyiccb2k2z8.ap-northeast-2.rds.amazonaws.com:3306/petclinic?useUnicode=true&characterEncoding=utf8&useSSL=false&serverTimezone=UTC</jdbc.url>
<jdbc.username>admin</jdbc.username>
<jdbc.password>${DB_PASSWORD}</jdbc.password>
```

### Kubernetes Secret
```bash
DB_PASSWORD=<RDS_비밀번호>
```

---

## 🎯 성공 지표

배포가 성공적으로 완료되었다면:
- ✅ Pod가 Running 상태
- ✅ LoadBalancer 외부 IP 할당됨
- ✅ 브라우저에서 `http://<EXTERNAL_IP>/petclinic` 접속 가능
- ✅ 펫클리닉 페이지 정상 로드
- ✅ 데이터베이스 데이터 조회 가능

---

## 📞 참고 자료

- AWS EKS 문서: https://docs.aws.amazon.com/eks/
- Kubernetes Service: https://kubernetes.io/docs/concepts/services-networking/service/
- Spring Boot: https://spring.io/projects/spring-boot
- MySQL JDBC: https://dev.mysql.com/downloads/connector/j/
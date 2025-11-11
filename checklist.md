# 펫클리닉 EKS + RDS 배포 실행 체크리스트

## 📋 배포 전 사전 준비 (필수)

### 1. AWS 및 kubectl 환경 준비
- [ ] AWS CLI 설치 및 자격증명 설정 완료
  ```bash
  aws configure --profile default
  aws sts get-caller-identity  # 확인
  ```
- [ ] kubectl 설치 완료
  ```bash
  kubectl version --client
  ```
- [ ] EKS 클러스터 kubeconfig 업데이트
  ```bash
  aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2
  kubectl get nodes  # 연결 확인
  ```

### 2. Docker 환경 준비
- [ ] Docker 설치 확인
  ```bash
  docker --version
  docker ps
  ```
- [ ] Docker 데몬 실행 확인

### 3. RDS 환경 준비
- [ ] RDS MySQL 인스턴스 상태 확인: **db-amazonvet**
  - 엔드포인트: `db-amazonvet.ciyiccb2k2z8.ap-northeast-2.rds.amazonaws.com`
  - 포트: 3306
  - 관리자 사용자: `admin`
  
- [ ] RDS 보안 그룹 설정 확인
  - **허용 규칙**: Worker Node 보안 그룹에서 포트 3306 TCP 허용
  - **Inbound Rule**: 
    - Type: MySQL/Aurora
    - Port: 3306
    - Source: EKS Worker Node 보안 그룹
  
- [ ] RDS 데이터베이스 생성 완료
  ```sql
  CREATE DATABASE IF NOT EXISTS petclinic CHARACTER SET utf8mb4;
  ```

### 4. EKS 클러스터 환경 확인
- [ ] EKS 클러스터 정상 작동 확인
  ```bash
  kubectl get nodes
  kubectl get svc --all-namespaces
  ```
- [ ] Worker Node 최소 1개 이상 Ready 상태
- [ ] VPC CNI 플러그인 설치 확인
  ```bash
  kubectl get daemonset -n kube-system aws-node
  ```

---

## 🚀 배포 실행 순서

### Step 1: 파일 준비
- [ ] 모든 파일을 한 디렉토리에 배치
  ```bash
  ls -la
  # 다음 파일들이 있어야 함:
  # - Dockerfile.springboot
  # - petclinic-deployment.yaml
  # - deploy.sh
  # - monitor.sh
  ```

- [ ] deploy.sh 실행 권한 확인
  ```bash
  chmod +x deploy.sh monitor.sh
  ```

### Step 2: 배포 자동화 실행
- [ ] deploy.sh 실행 (약 10-15분 소요)
  ```bash
  ./deploy.sh
  ```
  
  스크립트 실행 중 입력 항목:
  - [ ] RDS MySQL 비밀번호 입력 (admin 사용자의 비밀번호)

### Step 3: 배포 상태 확인
- [ ] Namespace 생성 확인
  ```bash
  kubectl get namespace | grep petclinic
  ```

- [ ] ConfigMap 생성 확인
  ```bash
  kubectl get configmap -n petclinic
  ```

- [ ] Secret 생성 확인
  ```bash
  kubectl get secret -n petclinic
  ```

- [ ] Deployment 배포 확인
  ```bash
  kubectl get deployment -n petclinic
  ```

- [ ] Pod 실행 확인 (Running 상태 대기)
  ```bash
  kubectl get pods -n petclinic -w
  # 모든 Pod이 Running 상태가 될 때까지 대기 (약 2-3분)
  ```

- [ ] Service 생성 확인
  ```bash
  kubectl get svc -n petclinic
  ```

### Step 4: LoadBalancer 외부 IP 확인
- [ ] 외부 IP 할당 확인 (약 2-5분 소요)
  ```bash
  kubectl get svc petclinic-lb -n petclinic
  # EXTERNAL-IP 컬럼에 *.elb.ap-northeast-2.amazonaws.com 형태의 주소 확인
  ```

### Step 5: 애플리케이션 접속 확인
- [ ] 브라우저에서 접속 테스트
  ```
  http://<EXTERNAL-IP>/petclinic
  ```
  - [ ] 페이지 정상 로드 확인
  - [ ] 메인 페이지 표시 확인

### Step 6: 데이터베이스 연동 확인
- [ ] 펫클리닉 데이터 조회 테스트
  - [ ] "Veterinarians" 메뉴 클릭 → 수의사 목록 표시
  - [ ] "Owners" 메뉴 클릭 → 소유자 목록 표시
  - [ ] 데이터베이스에서 정상 조회됨을 확인

---

## 🔍 모니터링 및 검증

### 실시간 모니터링 (선택사항)
```bash
./monitor.sh
```

### 수동 검증 명령어

**Pod 로그 확인**
```bash
kubectl logs -f $(kubectl get pods -n petclinic -o jsonpath='{.items[0].metadata.name}') -n petclinic
```

**Pod 내부 접속**
```bash
kubectl exec -it $(kubectl get pods -n petclinic -o jsonpath='{.items[0].metadata.name}') -n petclinic -- bash
```

**이벤트 확인**
```bash
kubectl get events -n petclinic --sort-by='.lastTimestamp'
```

---

## ⚠️ 배포 중 발생 가능한 문제 및 해결책

### 문제 1: Pod이 Pending 상태에서 머무름
**원인**: 리소스 부족 또는 노드 이슈

**해결책**:
```bash
# 상세 확인
kubectl describe pod <POD_NAME> -n petclinic

# 노드 상태 확인
kubectl get nodes
kubectl top nodes
```

### 문제 2: Pod이 CrashLoopBackOff 상태
**원인**: 대부분 RDS 연결 실패

**확인 항목**:
- [ ] RDS 비밀번호 정확성 확인
- [ ] RDS 보안 그룹 규칙 확인
  ```bash
  # AWS 콘솔에서 RDS 보안 그룹 확인:
  # Inbound: 3306 포트, EKS Worker Node 보안 그룹 소스
  ```
- [ ] RDS 엔드포인트 정확성 확인
- [ ] 로그 확인
  ```bash
  kubectl logs <POD_NAME> -n petclinic | head -100
  ```

### 문제 3: LoadBalancer 외부 IP가 계속 <pending> 상태
**원인**: AWS 리소스 할당 실패 또는 권한 부족

**해결책**:
```bash
# 서비스 상태 상세 확인
kubectl describe svc petclinic-lb -n petclinic

# 이벤트 확인
kubectl get events -n petclinic

# EKS 클러스터 권한 확인 (OIDC 설정 등)
```

### 문제 4: 데이터가 조회되지 않음
**원인**: RDS 데이터베이스 또는 테이블 미생성

**확인 항목**:
- [ ] RDS 데이터베이스 생성 확인
  ```sql
  SHOW DATABASES;
  -- petclinic 데이터베이스 존재 확인
  ```
- [ ] 테이블 생성 확인
  ```sql
  USE petclinic;
  SHOW TABLES;
  -- 7개 테이블 존재 확인:
  -- vets, specialties, vet_specialties, types, owners, pets, visits
  ```
- [ ] 초기 데이터 로드 확인
  ```sql
  SELECT COUNT(*) FROM vets;
  SELECT COUNT(*) FROM owners;
  ```

---

## 📊 검증 체크리스트 (배포 완료 확인)

배포 완료 후 다음을 확인하세요:

- [ ] **Pods 상태**
  ```bash
  kubectl get pods -n petclinic
  # STATUS: Running ✓
  # READY: 1/1 ✓
  ```

- [ ] **Deployment 상태**
  ```bash
  kubectl get deployment -n petclinic
  # READY: 2/2 ✓
  # AVAILABLE: 2 ✓
  # UP-TO-DATE: 2 ✓
  ```

- [ ] **Service 상태**
  ```bash
  kubectl get svc petclinic-lb -n petclinic
  # TYPE: LoadBalancer ✓
  # EXTERNAL-IP: (주소 할당됨) ✓
  # PORT(S): 80:XXXXX/TCP ✓
  ```

- [ ] **웹 접속**
  - [ ] http://<EXTERNAL-IP>/petclinic 정상 로드
  - [ ] 메뉴 항목 모두 클릭 가능
  - [ ] 데이터베이스 조회 성공

- [ ] **헬스체크**
  ```bash
  # Pod에서 헬스체크 성공 여부 확인
  kubectl logs <POD_NAME> -n petclinic | grep "health"
  ```

---

## 🧹 배포 제거 및 정리

배포를 완전히 제거하려면:

```bash
# 1. Namespace 삭제 (모든 리소스 함께 삭제)
kubectl delete namespace petclinic

# 2. ECR 이미지 삭제 (선택사항)
aws ecr delete-repository \
  --repository-name petclinic \
  --force \
  --region ap-northeast-2
```

---

## 📞 주요 리소스 정보

### RDS MySQL 정보
- **엔드포인트**: db-amazonvet.ciyiccb2k2z8.ap-northeast-2.rds.amazonaws.com
- **포트**: 3306
- **데이터베이스**: petclinic
- **사용자**: admin
- **리전**: ap-northeast-2

### EKS 클러스터 서브넷
- **Worker Node 서브넷**: 10.0.40.0/24, 10.0.50.0/24 (Private)
- **RDS 서브넷**: 10.0.60.0/24, 10.0.70.0/24 (Private)

### Kubernetes 리소스
- **Namespace**: petclinic
- **Deployment**: petclinic (replicas: 2)
- **Service (LoadBalancer)**: petclinic-lb
- **Service (ClusterIP)**: petclinic-svc
- **ConfigMap**: petclinic-config
- **Secret**: petclinic-db-secret

---

## 🎯 예상 완료 시간

| 단계 | 예상 시간 |
|------|----------|
| 사전 준비 | 10-15분 |
| Docker 이미지 빌드 | 5-8분 |
| ECR 푸시 | 2-3분 |
| Kubernetes 배포 | 3-5분 |
| Pod 시작 | 2-3분 |
| LoadBalancer 할당 | 2-5분 |
| **전체 예상 시간** | **25-40분** |

---

## ✅ 성공 신호

다음이 모두 완료되었다면 배포 성공입니다:

1. ✅ 모든 Pod이 Running 상태
2. ✅ LoadBalancer 외부 IP 할당됨
3. ✅ 브라우저에서 http://<EXTERNAL-IP>/petclinic 접속 가능
4. ✅ 펫클리닉 메인 페이지 정상 표시
5. ✅ 데이터베이스 데이터 조회 가능
6. ✅ Pod 헬스체크 정상

---

## 📝 추가 정보

더 자세한 내용은 다음 파일들을 참고하세요:
- `DEPLOY_GUIDE.md`: 전체 배포 가이드
- `Dockerfile.springboot`: Docker 이미지 설정
- `petclinic-deployment.yaml`: Kubernetes 배포 설정
- `deploy.sh`: 배포 자동화 스크립트
- `monitor.sh`: 모니터링 스크립트
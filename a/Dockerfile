# Stage 1: Build Spring Boot WAR
FROM maven:3.9-eclipse-temurin-21 AS builder

WORKDIR /app

# 펫클리닉 소스코드 클론 및 빌드
RUN git clone https://github.com/reynecat/github.git . && \
    mvn clean package -DskipTests

# Stage 2: Runtime
FROM tomcat:11-jdk21-temurin

# Tomcat 불필요한 default 앱 제거
RUN rm -rf /usr/local/tomcat/webapps/ROOT /usr/local/tomcat/webapps/docs \
    /usr/local/tomcat/webapps/examples /usr/local/tomcat/webapps/manager \
    /usr/local/tomcat/webapps/host-manager

# 빌드된 WAR 파일 복사
COPY --from=builder /app/target/*.war /usr/local/tomcat/webapps/ROOT.war

# Tomcat 포트 노출
EXPOSE 8080

# 헬스체크 추가 (EKS 자동 복구용)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# Tomcat 실행
CMD ["catalina.sh", "run"]
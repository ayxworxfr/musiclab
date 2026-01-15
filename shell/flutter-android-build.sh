#!/bin/sh
set -e

# 配置 Gradle 中国镜像
mkdir -p /root/.gradle/wrapper
echo 'distributionUrl=https://mirrors.cloud.tencent.com/gradle/gradle-7.5-all.zip' > /root/.gradle/wrapper/gradle-wrapper.properties

# 配置 Maven 中国镜像
mkdir -p /app/android/gradle
cat > /app/android/gradle/init.gradle << 'EOF'
allprojects {
    repositories {
        def ALIYUN_REPOSITORY_URL = 'https://maven.aliyun.com/repository/public'
        def ALIYUN_GRADLE_PLUGIN_URL = 'https://maven.aliyun.com/repository/gradle-plugin'
        def TENCENT_REPOSITORY_URL = 'https://mirrors.cloud.tencent.com/nexus/repository/maven-public'
        
        all { ArtifactRepository repo ->
            if (repo instanceof MavenArtifactRepository && repo.url.toString().startsWith('https://repo1.maven.org/maven2')) {
                project.logger.lifecycle "Repository ${repo.url} replaced by $ALIYUN_REPOSITORY_URL."
                remove repo
            }
            if (repo instanceof MavenArtifactRepository && repo.url.toString().startsWith('https://jcenter.bintray.com/')) {
                project.logger.lifecycle "Repository ${repo.url} replaced by $ALIYUN_REPOSITORY_URL."
                remove repo
            }
            if (repo instanceof MavenArtifactRepository && repo.url.toString().startsWith('https://dl.google.com/dl/android/maven2/')) {
                project.logger.lifecycle "Repository ${repo.url} replaced by $TENCENT_REPOSITORY_URL."
                remove repo
            }
        }
        
        maven { url ALIYUN_REPOSITORY_URL }
        maven { url ALIYUN_GRADLE_PLUGIN_URL }
        maven { url TENCENT_REPOSITORY_URL }
    }
}
EOF

# 配置 pub 缓存
mkdir -p /opt/flutter/.pub-cache
flutter config --no-analytics

# 接受 Android 许可证
yes | flutter doctor --android-licenses 2>/dev/null || true

# 使用中国镜像站更新 Flutter
flutter channel stable
flutter upgrade

# 正常构建流程
flutter clean
flutter pub get
flutter build apk --release --split-per-abi

# APK 重命名
APP_NAME=$(grep '^name:' pubspec.yaml | sed 's/name: //' | tr -d ' ')
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | sed 's/+.*//')
cd build/app/outputs/flutter-apk
for apk in app-*-release.apk; do
  if [ -f "$apk" ]; then
    ABI=$(echo "$apk" | sed 's/app-\(.*\)-release.apk/\1/')
    NEW_NAME="${APP_NAME}-v${VERSION}-android-${ABI}.apk"
    mv "$apk" "$NEW_NAME"
    echo "重命名: $apk -> $NEW_NAME"
  fi
done
echo "构建完成，APK文件已重命名"

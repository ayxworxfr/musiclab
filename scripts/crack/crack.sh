#!/bin/bash

LOG_FILE="/output/cracking_process.log"
echo "=== 密码破解过程日志 ===" > "$LOG_FILE"
echo "开始时间: $(date)" >> "$LOG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

mkdir -p /output

# 检查工具
if ! command -v hashcat &>/dev/null; then
    log "安装 hashcat..."
    apt-get update -qq
    apt-get install -y -qq hashcat unrar unzip p7zip-full 2>/dev/null
fi

# 检查字典
WORDLIST="/rockyou.txt"
if [ ! -f "$WORDLIST" ]; then
    log "错误: 未找到 rockyou.txt"
    exit 1
fi

log "字典文件: $WORDLIST ($(wc -l < "$WORDLIST") 行)"

# 查找压缩文件
TARGET_FILE=$(find /files -type f \( -name "*.rar" -o -name "*.zip" -o -name "*.7z" \) | head -n 1)

if [ -z "$TARGET_FILE" ]; then
    log "错误: 在 /files 目录中未找到压缩文件"
    exit 1
fi

FILENAME=$(basename "$TARGET_FILE")
EXTENSION="${FILENAME##*.}"
BASENAME="${FILENAME%.*}"
HASH_FILE="/tmp/hash.txt"
RESULT_FILE="/output/${BASENAME}_password.txt"

log "目标文件: $FILENAME"

# 检查文件是否需要密码
log "检查文件是否需要密码..."

# 对于 RAR 文件，尝试直接列出内容
if [ "$EXTENSION" = "rar" ]; then
    unrar l -p- "$TARGET_FILE" &>/dev/null
    if [ $? -eq 0 ]; then
        log "RAR文件没有密码保护"
        echo "文件: $FILENAME" > "$RESULT_FILE"
        echo "密码: [无密码]" >> "$RESULT_FILE"
        exit 0
    else
        log "RAR文件需要密码"
    fi
elif [ "$EXTENSION" = "zip" ]; then
    unzip -l "$TARGET_FILE" &>/dev/null
    if [ $? -eq 0 ]; then
        log "ZIP文件没有密码保护"
        echo "文件: $FILENAME" > "$RESULT_FILE"
        echo "密码: [无密码]" >> "$RESULT_FILE"
        exit 0
    else
        log "ZIP文件需要密码"
    fi
elif [ "$EXTENSION" = "7z" ]; then
    7z l "$TARGET_FILE" &>/dev/null
    if [ $? -eq 0 ]; then
        log "7Z文件没有密码保护"
        echo "文件: $FILENAME" > "$RESULT_FILE"
        echo "密码: [无密码]" >> "$RESULT_FILE"
        exit 0
    else
        log "7Z文件需要密码"
    fi
fi

# 提取哈希用于hashcat
log "提取哈希用于hashcat..."

# 为hashcat准备哈希
case "$EXTENSION" in
    rar)
        # 尝试使用hashcat内置的rar提取功能
        cp "$TARGET_FILE" /tmp/target.rar
        # RAR3-hp模式为13000, RAR5为13200
        HASH_MODE=13000
        log "使用hashcat模式 $HASH_MODE (RAR3-hp)"
        ;;
    zip)
        cp "$TARGET_FILE" /tmp/target.zip
        # ZIP模式为13600 (WinZip)
        HASH_MODE=13600
        log "使用hashcat模式 $HASH_MODE (ZIP)"
        ;;
    7z)
        cp "$TARGET_FILE" /tmp/target.7z
        # 7-Zip模式为11600
        HASH_MODE=11600
        log "使用hashcat模式 $HASH_MODE (7-Zip)"
        ;;
    *)
        log "不支持的格式: $EXTENSION"
        exit 1
        ;;
esac

# 使用hashcat破解
log "开始使用hashcat破解密码..."

# 检查是否有GPU可用
if hashcat -I &>/dev/null; then
    log "检测到hashcat可用，开始破解..."
    
    # 先尝试RAR3模式
    if [ "$EXTENSION" = "rar" ]; then
        log "尝试使用RAR3-hp模式 (13000)..."
        hashcat -m 13000 -a 0 -w 4 "/tmp/target.rar" "$WORDLIST" -o "/tmp/cracked.txt" 2>&1 | tee -a "$LOG_FILE"
        
        # 如果失败，尝试RAR5模式
        if [ ! -s "/tmp/cracked.txt" ]; then
            log "RAR3模式失败，尝试RAR5模式 (13200)..."
            hashcat -m 13200 -a 0 -w 4 "/tmp/target.rar" "$WORDLIST" -o "/tmp/cracked.txt" 2>&1 | tee -a "$LOG_FILE"
        fi
    else
        # 对于ZIP和7z使用之前确定的模式
        hashcat -m $HASH_MODE -a 0 -w 4 "/tmp/target.$EXTENSION" "$WORDLIST" -o "/tmp/cracked.txt" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # 检查是否找到密码
    if [ -s "/tmp/cracked.txt" ]; then
        PASSWORD=$(cat "/tmp/cracked.txt" | grep -o ':\K.*')
        log "✓ 密码找到: $PASSWORD"
        echo "文件: $FILENAME" > "$RESULT_FILE"
        echo "密码: $PASSWORD" >> "$RESULT_FILE"
        exit 0
    else
        log "hashcat未找到密码，尝试其他方法..."
    fi
else
    log "hashcat不可用或无法检测到GPU，尝试其他方法..."
fi

# 如果hashcat失败，尝试使用rarcrack（专门用于破解压缩文件密码）
if ! command -v rarcrack &>/dev/null; then
    log "安装rarcrack..."
    apt-get update -qq
    apt-get install -y -qq rarcrack 2>/dev/null || {
        log "无法安装rarcrack，尝试从源码编译..."
        apt-get install -y -qq build-essential libxml2-dev git
        git clone https://github.com/ziman/rarcrack /tmp/rarcrack
        cd /tmp/rarcrack
        make
        cp rarcrack /usr/local/bin/
    }
fi

if command -v rarcrack &>/dev/null; then
    log "使用rarcrack破解密码..."
    cp "$TARGET_FILE" "/tmp/target.$EXTENSION"
    cd /tmp
    rarcrack --type "$EXTENSION" "target.$EXTENSION" 2>&1 | tee -a "$LOG_FILE"
    
    # 检查rarcrack输出的XML文件
    RARCRACK_XML="/tmp/target.$EXTENSION.xml"
    if [ -f "$RARCRACK_XML" ]; then
        PASSWORD=$(grep -o '<password>.*</password>' "$RARCRACK_XML" | sed 's/<password>\(.*\)<\/password>/\1/')
        if [ -n "$PASSWORD" ] && [ "$PASSWORD" != "processing" ]; then
            log "✓ rarcrack找到密码: $PASSWORD"
            echo "文件: $FILENAME" > "$RESULT_FILE"
            echo "密码: $PASSWORD" >> "$RESULT_FILE"
            exit 0
        else
            log "rarcrack未找到密码"
        fi
    fi
else
    log "rarcrack不可用，尝试最后方法..."
fi

# 最后尝试使用fcrackzip（如果是ZIP文件）
if [ "$EXTENSION" = "zip" ] && ! command -v fcrackzip &>/dev/null; then
    log "安装fcrackzip..."
    apt-get update -qq
    apt-get install -y -qq fcrackzip 2>/dev/null
fi

if [ "$EXTENSION" = "zip" ] && command -v fcrackzip &>/dev/null; then
    log "使用fcrackzip破解ZIP密码..."
    fcrackzip -u -D -p "$WORDLIST" "$TARGET_FILE" 2>&1 | tee -a "$LOG_FILE"
    
    # 检查是否找到密码
    PASSWORD=$(fcrackzip -u -D -p "$WORDLIST" "$TARGET_FILE" 2>&1 | grep -o 'password: .*' | cut -d' ' -f2)
    if [ -n "$PASSWORD" ]; then
        log "✓ fcrackzip找到密码: $PASSWORD"
        echo "文件: $FILENAME" > "$RESULT_FILE"
        echo "密码: $PASSWORD" >> "$RESULT_FILE"
        exit 0
    else
        log "fcrackzip未找到密码"
    fi
fi

# 如果所有方法都失败，最后尝试使用cRARk（如果是RAR文件）
if [ "$EXTENSION" = "rar" ]; then
    log "所有方法都失败，尝试一些常见密码..."
    
    # 尝试一些常见密码
    COMMON_PASSWORDS=("password" "123456" "12345678" "abc123" "qwerty" "monkey" "letmein" "dragon" "111111" "baseball" "iloveyou" "trustno1" "1234567" "sunshine" "master" "welcome" "shadow" "ashley" "football" "jesus" "michael" "ninja" "mustang" "password1" "123123" "123456789" "654321" "superman" "qazwsx" "killer" "admin" "pass" "test")
    
    for pass in "${COMMON_PASSWORDS[@]}"; do
        log "尝试密码: $pass"
        unrar t -p"$pass" "$TARGET_FILE" &>/dev/null
        if [ $? -eq 0 ]; then
            log "✓ 密码找到: $pass"
            echo "文件: $FILENAME" > "$RESULT_FILE"
            echo "密码: $pass" >> "$RESULT_FILE"
            exit 0
        fi
    done
fi

log "✗ 所有方法都未找到密码"
exit 1

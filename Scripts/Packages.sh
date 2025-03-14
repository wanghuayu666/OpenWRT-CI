#!/bin/bash

# 安装和更新软件包
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_TAG=$3  # 使用标签版本
    local PKG_SPECIAL=$4
    local CUSTOM_NAMES=($5)  # 第5个参数为自定义名称列表
    local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)

    echo " "

    # 将 PKG_NAME 加入到需要查找的名称列表中
    if [ ${#CUSTOM_NAMES[@]} -gt 0 ]; then
        CUSTOM_NAMES=("$PKG_NAME" "${CUSTOM_NAMES[@]}")  # 将 PKG_NAME 添加到自定义名称列表的开头
    else
        CUSTOM_NAMES=("$PKG_NAME")  # 如果没有自定义名称，则只使用 PKG_NAME
    fi

    # 删除本地可能存在的不同名称的软件包
    for NAME in "${CUSTOM_NAMES[@]}"; do
        # 查找匹配的目录
        echo "Searching directory: $NAME"
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

        # 删除找到的目录
        if [ -n "$FOUND_DIRS" ]; then
            echo "$FOUND_DIRS" | while read -r DIR; do
                rm -rf "$DIR"
                echo "Deleted directory: $DIR"
            done
        else
            echo "No directories found matching name: $NAME"
        fi
    done

    # 删除现有的 lucky 目录（如果存在）
    if [ -d "$REPO_NAME" ]; then
        echo "$REPO_NAME directory already exists. Removing it."
        rm -rf $REPO_NAME
    fi

    # 如果是 lucky 插件，使用 pkg 方式
    if [[ $PKG_NAME == "lucky" ]]; then
        PKG_SPECIAL="pkg"  # 对 lucky 插件使用 pkg 处理方式
    fi

    # 克隆 GitHub 仓库并指定标签或分支
    git clone --depth=1 --single-branch --branch $PKG_TAG "https://github.com/$PKG_REPO.git"

    # 切换到指定标签版本
    cd $REPO_NAME
    git checkout $PKG_TAG  # 切换到指定标签或分支
    cd ..

    # 处理克隆的仓库
    if [[ $PKG_SPECIAL == "pkg" ]]; then
        find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
        rm -rf ./$REPO_NAME/
    elif [[ $PKG_SPECIAL == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
    fi
}

# 调用示例：lucky插件改为使用 pkg 方式处理
UPDATE_PACKAGE "lucky" "gdy666/lucky" "master" "pkg" ""  # 使用 master 分支，pkg 方式处理 lucky 插件

# 其他插件
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "luci-app-wol" "VIKINGYFY/packages" "main" "pkg"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "qmodem" "FUjr/modem_feeds" "main"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

# 添加 ttyd 插件
UPDATE_PACKAGE "ttyd" "tsl0922/ttyd" "main" "pkg"

# 更新软件包版本
UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-false}
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

    if [ -z "$PKG_FILES" ]; then
        echo "$PKG_NAME not found!"
        return
    fi

    echo -e "\n$PKG_NAME version update has started!"

    for PKG_FILE in $PKG_FILES; do
        local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
        local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
        local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
        local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
        local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

        local PKG_URL=$([[ $OLD_URL == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

        local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
        local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
        local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

        echo "old version: $OLD_VER $OLD_HASH"
        echo "new version: $NEW_VER $NEW_HASH"

        if [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "$PKG_FILE version has been updated!"
        else
            echo "$PKG_FILE version is already the latest!"
        fi
    done
}

# UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
UPDATE_VERSION "sing-box"
UPDATE_VERSION "tailscale"

# mpv-font-loader

这个脚本会在mpv启动时解析字幕文件并加载相关的字体, 灵感来自[FontLoaderSub](https://github.com/yzwduck/FontLoaderSub).

## 安装

1. 找到mpv的设置文件夹, 将font_loader目录放置在scripts文件夹下
2. 将font_loader.conf文件放置在script-opts目录下, 修改font_loader.conf, 将fontDir的值改为字体所在路径
3. 下载[cbor.lua](https://raw.githubusercontent.com/Zash/lua-cbor/refs/heads/master/cbor.lua), 将文件放置在scripts/font_loader目录下

## 注意事项

1. 需要预先使用FontLoaderSub生成fc-subs.db文件
2. Windows用户需要额外安装busybox, 并正确配置PATH环境变量
3. mpv最低版本需要为0.36.0
4. 安装完成后初次打开mpv会卡3-5s的时间, 这是脚本在解析fc-subs.db的内容, 之后再使用就不会卡顿了
5. 字幕文件中标注的字体较多时, 切换字幕会卡一下(自测只在Windows上出现此问题)

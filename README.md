# mpv-font-loader

这个脚本会在mpv启动时解析字幕文件并加载相关的字体, 灵感来自[FontLoaderSub](https://github.com/yzwduck/FontLoaderSub).

## 安装

1. 找到mpv的设置文件夹, 将font_loader目录放置在scripts文件夹下
2. 将font_loader.conf文件放置在script-opts目录下, 修改font_loader.conf, 将fontDir的值用户存放字体文件的目录
3. IINA用户需要开启[设置]-[高级]-[启用高级设置]

## 注意事项

1. 需要预先使用FontLoaderSub生成fc-subs.db文件
2. Windows用户需要额外安装[**busybox**](https://frippery.org/busybox/), 并正确配置PATH环境变量
3. mpv最低版本需要为0.36.0
4. 安装完成后初次打开mpv会卡3-5s的时间, 这是脚本在解析fc-subs.db的内容, 之后再使用就不会卡顿了
5. 字幕文件中标注的字体较多时, 切换会卡一下(自测只在Windows上出现此问题)

## 原理

创建一个临时文件夹, 在文件夹中创建相关字体文件的符号链接, 将该文件夹的路径赋给mpv的sub-fonts-dir

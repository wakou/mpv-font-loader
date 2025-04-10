# mpv-font-loader

这个脚本会在mpv启动时解析字幕文件并加载相关的字体, 灵感来自[FontLoaderSub](https://github.com/yzwduck/FontLoaderSub).

## 安装

下载[lua-cbor](https://raw.githubusercontent.com/Zash/lua-cbor/refs/heads/master/cbor.lua)到`font_loader`目录下(从Release下载的不需要进此操作)

### MPV

1. 找到mpv的设置文件夹, 将`font_loader`目录放置在scripts文件夹下
2. 将font_loader.conf文件放置在script-opts目录下, 修改font_loader.conf, 将fontDir的值改为用户存放字体文件的目录

### IINA

IINA用户需要进入[设置]-[高级]菜单, 打开`启用高级设置`选项

* 使用配置目录
  
  1. 勾选`使用配置目录`, 并选择配置目录(下面以```~/.config/iina/```为例)
  2. 在目录```~/.config/iina/```下新建文件夹`scripts`和`script-opts`
  3. 将font_loader目录放置在scripts文件夹下, font_loader.conf文件放置在script-opts目录下
  4. 修改font_loader.conf, 将fontDir的值改为用户存放字体文件的目录

* 不使用配置目录
  
  1. 不勾选`使用配置目录`, 以下操作假定脚本路径为`~/mpv_script/font_loader`
  2. 在`额外mpv选项`栏中添加两个选项`scripts`, `script-opts`
  3. 设置scripts选项的值为脚本所在路径, 即`~/mpv_script/font_loader`, 若需添加多个脚本, 则脚本路径以逗号`,`分割, 如`~/mpv_script/font_loader,~/mpv_script/scriptA`
  4. 设置script-opts选项的值为`font_loader-fontDir=字体目录,font_loader-fontIndexFile=customDir/font-index,font_loader-cacheDir=customDir1`, 根据实际情况替换`字体目录`, `customDir`, `customDir1`的值

## 注意事项

1. **目前只支持UTF-8编码的ass字幕文件**
2. 需要预先使用FontLoaderSub生成fc-subs.db文件
3. mpv最低版本需要为0.36.0
4. 安装完成后初次打开mpv会卡3-5s的时间, 这是脚本在解析fc-subs.db的内容, 之后再使用就不会卡顿了
5. 字幕文件中标注的字体较多时, 切换会卡一下(自测只在Windows上出现此问题)

## TODO

* [ ] 支持UTF16编码字幕文件
* [ ] 支持GBK编码字幕文件

## 原理

创建一个临时文件夹, 在文件夹中创建相关字体文件的符号链接, 将该文件夹的路径赋给mpv的`sub-fonts-dir`属性

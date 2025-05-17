# mpv-font-loader

这个脚本会在mpv启动时解析字幕文件并加载相关的字体, 灵感来自[FontLoaderSub](https://github.com/yzwduck/FontLoaderSub).

通过`uchardet`与`libiconv`实现了字幕文件编码的检测与转换, 依赖库来自[`Conan`](https://conan.io/)

## 安装

Windows用户须先参考`关于在Windows下使用的特别说明`进行授权操作

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

## 使用

安装完成后, 打开任意视频即可

### 字体库更新

若用户有在字体文件夹中添加了新的字体, 需使用`FontLoaderSub`重新生成`fc-subs.db`, 并在字体文件夹下创建`update.txt`文件(文件内容为空即可)，脚本检测到此文件会自动更新缓存

## 注意事项

1. 需要预先使用FontLoaderSub生成fc-subs.db文件
2. mpv最低版本需要为0.36.0, 该版本开始支持`sub-fonts-dir`属性
3. 安装完成后初次打开mpv会卡3-5s的时间, 这是脚本在解析fc-subs.db的内容, 之后会生成索引文件, 减少加载时间
4. 字幕文件中标注的字体较多时, 切换会卡一下(自测只在Windows上出现此问题)
5. 在Windows系统下, 默认情况下可能无权限创建软链接, 需打开相关权限

## 关于在Windows下使用的特别说明

本脚本的运行需要进行创建软链接的操作。但在Windows系统上，默认是无权限创建软链接的，因此需先取得权限。

以下操作只在Win10上测试过，但应该也适用于Win11

### 对于系统为家庭版，教育版等版本的

1. 打开设置，进入【更新和安全】-【开发者选项】页面
2. 打开开发人员模式

### 对于系统为专业版及以上版本的

专业版除了像家庭版那样开启开发人员模式外，还可选择为当前用户单独打开创建软链接权限。

#### 通过gui操作

1. 打开程序【本地安全策略】
2. 在程序中进入【本地策略】-【用户权限分配】-【创建符号链接】
3. 在【创建符号链接 属性】选项卡中，点击【添加用户或组】
4. 输入你的账号名，点击【检查名称】，然后点击确定

#### 通过脚本操作

1. 下载"allowCreateSymbolicLink.ps1"脚本
2. PowerShell默认不允许执行脚本, 需以管理员权限打开powershell, 输入"Set-ExecutionPolicy RemoteSigned"
3. 执行"allowCreateSymbolicLink.ps1"脚本

## 实现思路

利用了mpv的`sub-fonts-dir`属性. 视频文件载入时, 创建一个临时文件夹, 扫描并解析加载的外置字幕文件所使用的字体, 在文件夹中创建相关字体文件的符号链接, 将该文件夹的路径赋给mpv的`sub-fonts-dir`属性, mpv将会加载该属性所指文件夹中的字体

## TODO

* [x] 支持UTF16编码字幕文件
* [x] 支持GBK编码字幕文件
* [x] 支持其它编码格式
* [ ] 实现`fc-subs.db`文件的变动检查, 并自动更新字体索引文件
* [ ] 实现字体库文件夹的扫描, 去除对`fc-subs.db`文件的依赖

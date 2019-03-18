# special-script

处理个人Lnux系统使用时一些特殊需求的脚本

## extdp.sh

方便 Linux 在 4k/Retina 屏笔记本上扩展外接显示器的小工具

### 依赖工具

主要用到了 `xrandr`，因为个人笔记本有NVIDIA的显卡，安装了`nvidia-drivers`的闭源驱动，使用NVIDIA显卡会导致scale时黑屏的情况发生，所以同时需要给`nvidia-settings`命令添加`ForceFullCompositionPipeline=On`的参数

### 参考资料
> - [archlinux wiki HiDPI](https://wiki.archlinux.org/index.php/HiDPI)
> - [askubuntu.com](https://askubuntu.com/questions/704503/scale-2x2-in-xrandr-causes-the-monitor-to-not-display-anything/979551#979551)

## rotate.sh

解决翻转屏幕后鼠标，触摸板等方向不能同时同步更改的问题

### 依赖工具

- `xrandr`
- `xinput`

## sundry.sh

杂项

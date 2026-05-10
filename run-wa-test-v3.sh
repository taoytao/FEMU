#!/bin/bash
# 4K随机写 + 16GB FEMU SSD（稳定版）

IMGDIR=$HOME/images
OSIMGF=$IMGDIR/u20s.qcow2
QEMU_PATH="/home/taoytao/Project/FEMU/build-femu/qemu-system-x86_64"

# ==================== FEMU 16GB 参数 ====================
secsz=512
secs_per_pg=8
pgs_per_blk=256
blks_per_pl=256
pls_per_lun=256
luns_per_ch=4
nchs=8
ssd_size=16384  # 16GB

pg_rd_lat=40000
pg_wr_lat=200000
blk_er_lat=2000000
ch_xfer_lat=0

gc_thres_pcent=75
gc_thres_pcent_high=95

# 拼接
FEMU_OPTIONS="-device femu"
FEMU_OPTIONS=${FEMU_OPTIONS}",devsz_mb=${ssd_size}"
FEMU_OPTIONS=${FEMU_OPTIONS}",namespaces=1"
FEMU_OPTIONS=${FEMU_OPTIONS}",femu_mode=1"
FEMU_OPTIONS=${FEMU_OPTIONS}",secsz=${secsz}"
FEMU_OPTIONS=${FEMU_OPTIONS}",secs_per_pg=${secs_per_pg}"
FEMU_OPTIONS=${FEMU_OPTIONS}",pgs_per_blk=${pgs_per_blk}"
FEMU_OPTIONS=${FEMU_OPTIONS}",blks_per_pl=${blks_per_pl}"
FEMU_OPTIONS=${FEMU_OPTIONS}",pls_per_lun=${pls_per_lun}"
FEMU_OPTIONS=${FEMU_OPTIONS}",luns_per_ch=${luns_per_ch}"
FEMU_OPTIONS=${FEMU_OPTIONS}",nchs=${nchs}"
FEMU_OPTIONS=${FEMU_OPTIONS}",pg_rd_lat=${pg_rd_lat}"
FEMU_OPTIONS=${FEMU_OPTIONS}",pg_wr_lat=${pg_wr_lat}"
FEMU_OPTIONS=${FEMU_OPTIONS}",blk_er_lat=${blk_er_lat}"
FEMU_OPTIONS=${FEMU_OPTIONS}",ch_xfer_lat=${ch_xfer_lat}"
FEMU_OPTIONS=${FEMU_OPTIONS}",gc_thres_pcent=${gc_thres_pcent}"
FEMU_OPTIONS=${FEMU_OPTIONS}",gc_thres_pcent_high=${gc_thres_pcent_high}"

echo "FEMU 配置（16GB）: ${FEMU_OPTIONS}"

if [[ ! -e "$OSIMGF" ]]; then
    echo "错误：找不到镜像 $OSIMGF"
    exit 1
fi

RESULT_DIR="./wa-test-results-16g"
mkdir -p $RESULT_DIR

# ==================== 启动 QEMU ====================
echo "启动 16GB FEMU 虚拟机..."
sudo $QEMU_PATH \
-name "FEMU-16G-SSD-VM" \
-machine type=pc,accel=tcg \
-cpu qemu64 \
-smp 4 \
-m 4G \
-device virtio-scsi-pci,id=scsi0 \
-device scsi-hd,drive=hd0 \
-drive file=$OSIMGF,if=none,aio=native,cache=none,format=qcow2,id=hd0 \
${FEMU_OPTIONS} \
-net user,hostfwd=tcp::8080-:22 \
-net nic,model=virtio \
-nographic \
-qmp unix:./qmp-sock,server,nowait > $RESULT_DIR/vm.log 2>&1 &

VM_PID=$!
echo "VM PID: $VM_PID"

echo "等待 60 秒启动（16GB 初始化较慢）..."
sleep 60

# ==================== SSH 执行 4K 随机写 ====================
echo "连接虚拟机执行测试..."
ssh -o StrictHostKeyChecking=no -p 8080 root@localhost << 'EOF' > $RESULT_DIR/test_output.log 2>&1
if ! command -v fio &> /dev/null; then
    apt update && apt install -y fio
fi

echo "设备: /dev/sda"

cat > /tmp/randwrite.fio << FIOEOF
[global]
ioengine=libaio
direct=1
rw=randwrite
bs=4k
iodepth=32
numjobs=1
time_based
runtime=1800
group_reporting
bw_limit=40M
filename=/dev/sda
name=4k-randwrite-16g
FIOEOF

echo "========== 开始 4K 随机写（16GB SSD） =========="
fio /tmp/randwrite.fio
echo "========== 测试结束 =========="
EOF

# 收集统计
echo "收集 FEMU 统计..."
echo '{"execute":"qmp_capabilities"}' | nc -U ./qmp-sock > /dev/null 2>&1
echo '{"execute":"x-femu","arguments":{"opcode":5}}' | nc -U ./qmp-sock > $RESULT_DIR/femu_stats.json 2>&1

# 关闭
echo "关闭虚拟机..."
kill $VM_PID
wait $VM_PID 2>/dev/null

# 结果
echo -e "\n=========================================="
echo "测试完成！结果: $RESULT_DIR/"
echo "=========================================="
grep -A 20 "4k-randwrite-16g" $RESULT_DIR/test_output.log
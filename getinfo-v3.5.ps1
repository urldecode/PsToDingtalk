#-------------------------------------------------------------------------------------------------------------
# Exp:       获取服务器基本信息，Name，OS，IP，内存，CPU，磁盘容量，磁盘健康并转为json的脚本，或者通过webhook接口发送钉钉消息
# Author:    XXX
# Date:      2021/10/22 23：00
# Version:   2021.10.v3.5

# 更新内容:   2021.10.v.1   检测结果存在本地文件
#            2021.10.v.2  检测结果转化为json，可以后期对接数据库
#            2021.10.v3.1 支持 DingTalk
#            2021.10.v3.2 对发送钉钉的markdown内容格式进行了重新排版和优化，对整体代码进行=号的对齐
#            2021.10.v3.3 优化多次盘发送钉钉内容，暂时支持3个磁盘的容量信息
#            2021.10.v3.4 采用循环数组方法，优化磁盘信息和健康度发送钉钉的代码，显示结果不限制磁盘数量
#            2021.10.v3.5 优化markdown数据，修复磁盘占用率显示为剩余率的bug,优化cpu显示bug
#-------------------------------------------------------------------------------------------------------------

#
$Server    =  $env:COMPUTERNAME
$ServerOS  = (Get-WmiObject -Class Win32_OperatingSystem).Caption
$Cpu       =  Get-WmiObject -ComputerName $Server win32_Processor
$Mem       =  Get-WmiObject -ComputerName $Server win32_OperatingSystem
$Disks     =  Get-WmiObject -ComputerName $Server win32_logicaldisk -filter "drivetype=3"

#获取内存信息
$MemTotal  = "{0:0.0}GB" -f ($Mem.TotalVisibleMemorySize/ 1MB)
$MemFree   = "{0:0.0}GB" -f ($Mem.FreePhysicalMemory/ 1MB)
$MemPer    = "{0:0.0}%"  -f ((($Mem.TotalVisibleMemorySize-$Mem.FreePhysicalMemory)/$Mem.TotalVisibleMemorySize)*100)

#获取IP信息
$ServerIP = @()
$ServerIP = ((Get-WmiObject -class win32_NetworkAdapterConfiguration -Filter 'ipenabled = "true"').ipaddress -notlike "*:*" -join " | ")

#获取CPU信息
$CpuNum    = $Cpu.Count
$CpuName   = $Cpu.Name
$CpuThread = $Cpu.NumberOfLogicalProcessors
$CpuCore   = $Cpu.NumberOfCores
$CpuPer    = "{0:0.0}%" -f $Cpu.LoadPercentage

#获取磁盘使用情况
$DisksList  = @{}
$Disks | Foreach-Object {        
    $DisksPation = '{0}'    -f   $_.Caption        
    $DisksSize   = '{0:0}G' -f  ($_.Size / 1024MB)        
    $DisksFree   = '{0:0}G' -f  ($_.FreeSpace / 1024MB)        
    $DisksPer    = '{0:0}%' -f ((1-$_.FreeSpace/$_.Size)*100)          
    $DisksName   = '{0:0}'  -f   $_.VolumeName
    #结构化数据，并且添加数据
    $DisksList.$DisksPation = [ordered]@{
                DisksPation = "$DisksPation";
                DisksName   = "$DisksName";
                DisksSize   = "$DisksSize"; 
                DisksFree   = "$DisksFree"; 
                DisksPer    = "$DisksPer"} 
    #以下为了方便发送钉钉消息，循环添加磁盘信息到数组，并且进行嵌套
     $DisksInfo   = @( $DisksPation , $DisksName , $DisksSize , $DisksFree , $DisksPer)  
     $DisksLists += @($DisksInfo)  
    } 

#写磁盘信息markdown结构数据
Function DingtalkDisksInfo {
  for ($index = 0 ;$index -lt $DisksLists.Count/5 ; $index++ ){
      "### 盘符 {0}`n" -f $DisksLists[$index*5]
      "* 磁盘名  ：{0}`n" -f $DisksLists[$index*5+1]
      "* 总量    ：{0}`n" -f $DisksLists[$index*5+2]
      "* 剩余    ：{0}`n" -f $DisksLists[$index*5+3]
      "* 占用率  ：{0}`n" -f $DisksLists[$index*5+4]
    }
  }

#获取磁盘健康情况和其他基本信息
$DisksHealth = @{}
$(Get-Disk) | ForEach-Object{
    $Number  = $_.Number
    $FriName = $_.FriendlyName
#   $SN = $_.SerialNumber
    $HealthStatus =   $_.HealthStatus
    $OpStatus     =   $_.OperationalStatus
    $TotalSize    =  '{0:0}G' -f ($_.Size / 1024MB)
    #结构化数据，并且添加数据
    $DisksHealth.$Number = [ordered]@{
                  Number = "$Number"; 
                  FriendName   = $FriName; 
                  HealthStatus = $HealthStatus; 
                  OpStatus     = $OpStatus; 
                  TotalSize    = $TotalSize}
    #磁盘健康度，数组，
    $DisksHealthInfo   =   @($Number,$FriName,$HealthStatus,$OpStatus,$TotalSize)
    $DisksHealthLists += @(@($DisksHealthInfo))
    }

#写磁盘健康度markdown结构数据
Function DingtalkHealthInfo {
  for ($index = 0 ;$index -lt $DisksHealthLists.Count/5 ; $index++ ){
      "### 序号 {0}`n" -f $DisksHealthLists[$index*5]
      "* 磁盘名    ：{0}`n" -f $DisksHealthLists[$index*5+1] 
      "* 磁盘健康  ：{0}`n" -f $DisksHealthLists[$index*5+2] 
      "* 磁盘状态  ：{0}`n" -f $DisksHealthLists[$index*5+3]
      "* 磁盘大小  ：{0}`n" -f $DisksHealthLists[$index*5+4]
    }
  }


#获取当前脚本执行时间
$Date = Get-Date -Format 'yyyy-M-dd-HH:mm'


#对象化数据
$Body = [ordered]@{
    ServerName  = "$Server";
    ServerOS    = "$ServerOS";
    ServerIP    = "$ServerIP";
    Date        = "$Date";
    CpuInfo     = [ordered]@{
            CpuPer    = "$CpuPer";
            CpuCore   = "$CpuCore";
            CpuThread = "$CpuThread";
            CpuName   = "$CpuName"}
    MemInfo           = [ordered]@{
            MemTotal  = "$MemTotal";
            MemFree   = "$MemFree";
            MemPer    = "$MemPer";}
}

#添加一些其他结构数据
$Body.DiskInfo   = $DisksList.Values
$Body.HealthInfo = $DisksHealth.Values

#转换为json数据格式
$Json = $Body | ConvertTo-Json

#post地址
#$Uri = 'https://xxxxx'

#定义post中的传输数据类型
#$Headers = @{"accept"="application/json"}

#输出json数据方便调试改进
Write-Host $Json

#post json请求
#curl -Uri $Uri -Method POST -Body $Json

#################################
#下面为发送到钉钉接口的请求格式 #
#################################

#通过数组循环调用解决需要手动进行定义，大大优化了代码

$MarkdownDiskInfo   = DingtalkDisksInfo
$MarkdownHealthInfo = DingtalkHealthInfo

Function DingTalkApi($msg){
$Uri = "https://oapi.dingtalk.com/robot/send?access_token=xxxxxxxxxxxxxxxx"
$PostBody="{
`"markdown`":{
`"title`":`"服务器信息  $ServerIP`",
`"text`":`"
# 服务器信息 $Server
## **ServerInfo**
  * IP    :  $ServerIP
  * ServerName:  $Server
  * OS    :  $ServerOS
  * Date  :  $Date
## **CPU信息**
  * 核心数  ： $CpuNum
  * 占用率  :  $CpuPer
  * 内核    :  $CpuCore
  * 线程数  :  $CpuThread
  * 型号    :  $CpuName
## **内存信息**
  * 总量    :  $MemTotal
  * 剩余    :  $MemFree
  * 占用率  :  $MemPer    
## **磁盘信息**
$MarkdownDiskInfo
## **磁盘健康度**
$MarkdownHealthInfo
`"
},
`"msgtype`":`"markdown`"
}"
Write-Host $PostBody
$DingTalk = [System.Text.Encoding]::UTF8.GetBytes($PostBody)
invoke-WebRequest $uri -Method "POST" -ContentType "application/json" -Body $DingTalk
}

DingTalkApi -msg a
################################

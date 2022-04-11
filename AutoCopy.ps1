#-------------------------------------------------------------------------------------------------------------
# Exp:       检查备份情况，对失败的备份进行补全，并把备份情况发送钉钉
# Author:    LHJ
# Date:      2022/04/11 23：00
# Version:   2022.04.v3
# 更新内容   2022.04.v.1   检查备份情况，对失败的备份进行补全，并把备份情况发送钉钉
#            2022.04.v.2
#            2022.04.v.3   优化了判断
#-------------------------------------------------------------------------------------------------------------


#定义静态文件路径
$ServerName = "Powershell Test"
$SourcePath = "D:\powershell\source"
$LogPath    = "D:\powershell\log"
$GetTimeFile = "$LogPath\vhdx.txt"
$CreateTime  = (Get-ChildItem $GetTimeFile).CreationTime.ToString('M-d-yyyy')
$DestPath    = "D:\powershell\dest\"
$appPath    = "C:\Users\Administrator\Desktop\Script"

#获取最后修改的文件名，和修改时间
$Last       = Get-ChildItem $LogPath | Sort-Object lastwritetime -Descending
$LastFile   = $Last.Name[0]
$LastFilePath = "$LogPath\$LastFile"
$LastTime   = $Last.LastWriteTime[0]

#创建两个数组
$SendMsg    = @()
$FailList   = @()

#备份是否完成 
if ($LastFilePath -like "*report*"){
    #成功数量
    $OKNum = (Select-String "成功" $LastFilePath).count
    #失败的文件列表和数量
    $Fail = Select-String "失败" $LastFilePath 
    $FailList = $Fail | ForEach-Object{([string]$_).Split(" ")[0]} | ForEach-Object{$_.Split(":")[3]}
    $FailNum =$Fail.count 
    #检查失败列表文件
    #如果没有FailList.txt不存在新建一个
    $FailText = Get-Content $appPath\FailList.txt
    #如果失败列表不为空则进行复制
    if ($Null -eq $FailList ){
        $SendMsg += @("#####  备份完成  \n")
        $SendMsg += @("#####  完成日期 ： $LastTime \n")
        $SendMsg += @("#####  成功数量 ： $OKNum \n ")
        Write-Output "Success" >  $appPath\FailList.txt
    }
    elseif ($Null -ne (Compare-Object $FailList $FailText)){
        $SendMsg += @("#####  备份完成 \n ")
        $SendMsg += @("#####  完成时间 ： $LastTime \n ")
        $SendMsg += @("#####  成功数量 ： $OKNum \n ")
        $SendMsg += @("#####  失败数量 ： $FailNum \n ")
        # 失败的文件列表与文本列表一样吗
        $SendMsg += @("#####  开始备份 \n ")
        ForEach ($File in $FailList){
            $SourceFileTrue = (Test-Path $SourcePath\$File).ToString()
            $DestFileFalse  = (Test-Path $DestPath\$File).ToString()
            # 源文件是否存在 ，目标文件是否存在
            if ($SourceFileTrue -eq "True" -And $DestFileFalse -eq "False"){
                Copy-Item $SourcePath\$File $DestPath
                $Date = Get-Date
                $SendMsg += @("#####  复制完成 ： $File \n ")
                $SendMsg += @("#####  完成时间 ： $Date \n ")
            }
            elseif ($SourceFileTrue -eq "False"){
                $SendMsg += @("#####  源文件 $File 不存在 \n ")
            }
            else {
                $SendMsg += @("#####  目标文件 $File 已存在 \n ")
            }
        }
        Write-Output $FailList > $appPath\FailList.txt
    }
    # 两次对比一致
    else{
        $SendMsg += @("#####  已备份完成   \n")
        $SendMsg += @("#####  完成时间 ： $LastTime")
        }           
    
}
#备份中
elseif($LastFilePath -like "*log*"){
    $SendMsg += @("#####  备份中  \n ")
    $SendMsg += @("#####  备份时间 ：$LastTime  \n ")
    $SendMsg += @("#####  最后写入 ：$LastFile  \n ")
    }
#其他
else{
    $SendMsg += @("#####  检查最后写入文件  \n ")
    }

Function DingTalkApi($msg){
$Uri = "https://oapi.dingtalk.com/robot/send?access_token=xxxxxxxxxxxxxxxxxx"
$PostBody="{
`"markdown`":{
`"title`":`"备份状态  $ServerName`",
`"text`":`"
### $ServerName 备份状态
-----------------------
$SendMsg
-----------------------
`"
},
`"msgtype`":`"markdown`"
}"
Write-Host $PostBody
$DingTalk = [System.Text.Encoding]::UTF8.GetBytes($PostBody)
invoke-WebRequest $uri -Method "POST" -ContentType "application/json" -Body $DingTalk
}

DingTalkApi -msg a

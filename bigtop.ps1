$env:DOCKER_IMAGE="bigtop/puppet:centos-7"
$env:MEM_LIMIT="4g"
$env:PROVISION_ID="20171101_015046_R21652"

Get-ChildItem env:
Get-ChildItem env:MEM_LIMIT
Get-ChildItem env:DOCKER_IMAGE

### Share drive in windows docker settings
docker-compose.exe -p 20171101_015046_R21652 scale bigtop=3

$env:NODES=$(docker-compose -p $env:PROVISION_ID ps -q)
$NODES=$env:NODES.Split(' ')
$env:hadoop_head_node=$(docker inspect --format '{{.Config.Hostname}}.{{.Config.Domainname}}' $env:NODES[0])

$yaml="config.yaml"
$repo="http://bigtop-repos.s3.amazonaws.com/releases/1.2.0/centos/7/x86_64"
$components="[`[hdfs,yarn,mapreduce]"
$jdk=([String]$(Select-String jdk $yaml)).Split(' ')[1]
$distro=([String]$(Select-String distro $yaml)).Split(' ')[1]
$enable_local_repo=([String]$(Select-String enable_local_repo $yaml)).Split(' ')[1]


### generate-hosts
$NODES | ForEach-Object {
    write-Output "Add conf for $_"
    $entry=$(docker inspect --format '{{.NetworkSettings.IPAddress}} {{.Config.Hostname}}.{{.Config.Domainname}} {{.Config.Hostname}}' $_)
    docker exec $($NODES[0]) bash -c "echo $entry >> /etc/hosts"
    Write-Output "$entry"
}

<# wait
# This must be the last entry in the /etc/hosts
echo "127.0.0.1 localhost" >> ./config/hosts #>

### bootstrap
$NODES | % {
    docker exec $_ bash -c "/bigtop-home/provisioner/utils/setup-env-$distro.sh $enable_local_repo" -d
}

### provision
## bigtop-puppet
$NODES | % {
    Write-Output "docker exec $_ bash -c `"puppet apply --parser future --modulepath=/bigtop-home/bigtop-deploy/puppet/modules:/etc/puppet/modules /bigtop-home/bigtop-deploy/puppet/manifests`" -d"
    docker exec $_ bash -c "puppet apply --parser future --modulepath=/bigtop-home/bigtop-deploy/puppet/modules:/etc/puppet/modules /bigtop-home/bigtop-deploy/puppet/manifests" -d
}









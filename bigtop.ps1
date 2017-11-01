$env:DOCKER_IMAGE="bigtop/puppet:centos-7"
$env:MEM_LIMIT="4g"
$env:PROVISION_ID="20171101_015046_R21652"

Get-ChildItem env:
Get-ChildItem env:MEM_LIMIT
Get-ChildItem env:DOCKER_IMAGE

$RANDOM=Get-Random
$PROVISION_ID="$(get-date -UFormat `"%Y%m%d_%H%M%S`")_$RANDOM"
### Share drive in windows docker settings
docker-compose.exe -p 20171101_015046_R21652 scale bigtop=3
$BIGTOP_PUPPET_DIR=../../bigtop-deploy/puppet

### generate-config
New-item -Path ".\config" -ItemType "Directory"
New-item -Path ".\config" -Name "hiera.yaml" -ItemType "File"
New-item -Path ".\config" -Name "hosts" -ItemType "File"
New-item -Path "." -Name ".provision_id" -ItemType "File" -Value "$PROVISION_ID"
cat "$BIGTOP_PUPPET_DIR/hiera.yaml" >> "./config/hiera.yaml"
Copy-Item -Path "$BIGTOP_PUPPET_DIR/hieradata" -Destination "./config" -Recurse 

$env:NODES=$(docker-compose -p $env:PROVISION_ID ps -q)
$NODES=$env:NODES.Split(' ')
$env:hadoop_head_node=$(docker inspect --format '{{.Config.Hostname}}.{{.Config.Domainname}}' $env:NODES[0])

$yaml="config.yaml"
$repo="`"http://bigtop-repos.s3.amazonaws.com/releases/1.2.0/centos/7/x86_64`""
$components="`"[hdfs,yarn,mapreduce]`""
$jdk=([String]$(Select-String jdk $yaml)).Split(' ')[1]
$distro=([String]$(Select-String distro $yaml)).Split(' ')[1]
$enable_local_repo=([String]$(Select-String enable_local_repo $yaml)).Split(' ')[1]

Add-Content "./config/hieradata/site.yaml" "bigtop::hadoop_head_node: `"$env:hadoop_head_node`""
Add-Content "./config/hieradata/site.yaml" "hadoop::hadoop_storage_dirs: [/data/1, /data/2]"
Add-Content "./config/hieradata/site.yaml" "bigtop::bigtop_repo_uri: $repo"
Add-Content "./config/hieradata/site.yaml" "hadoop_cluster_node::cluster_components: $components"
Add-Content "./config/hieradata/site.yaml" "bigtop::jdk_package_name: $jdk"


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

<# docker exec b50ebf654fda75bead4966353f4be96f302f53c49f06cf1137ee69321f2f1012 bash -c "puppet apply --parser future --modulepath=/bigtop-home/bigtop-deploy/pupp
et/modules:/etc/puppet/modules /bigtop-home/bigtop-deploy/puppet/manifests" -d
Warning: This method is deprecated, please use match expressions with Stdlib::Compat::Bool instead. They are described at https://docs.puppet.com/puppet/latest
/reference/lang_data_type.html#match-expressions.
   (at /etc/puppet/modules/stdlib/lib/puppet/functions/deprecation.rb:25:in `deprecation')
Error: Evaluation Error: Error while evaluating a Function Call, Could not find data item bigtop::hadoop_head_node in any Hiera data file and no default suppli
ed at /bigtop-home/bigtop-deploy/puppet/manifests/cluster.pp:172:23 on node b50ebf654fda.bigtop.apache.org
Error: Evaluation Error: Error while evaluating a Function Call, Could not find data item bigtop::hadoop_head_node in any Hiera data file and no default suppli
ed at /bigtop-home/bigtop-deploy/puppet/manifests/cluster.pp:172:23 on node b50ebf654fda.bigtop.apache.org
 #>







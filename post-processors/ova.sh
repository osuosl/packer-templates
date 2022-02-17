#!/bin/bash -eu
[ -z "${OUTPUT_DIR}" ] && echo "OUTPUT_DIR not set" && exit 1
[ -z "${IMAGE_NAME}" ] && echo "IMAGE_NAME not set" && exit 1
[ -z "${TARGET_SIZE}" ] && echo "TARGET_SIZE not set" && exit 1
[ -z "${OS_TYPE}" ] && echo "OS_TYPE not set" && exit 1
[ -z "${OS_ID}" ] && echo "OS_ID not set" && exit 1
[ -z "${OS_DESCRIPTION}" ] && echo "OS_DESCRIPTION not set" && exit 1

DISK_RAW="disk"

cd "${OUTPUT_DIR}"

mv "${IMAGE_NAME}" "${DISK_RAW}"
IMAGE_SIZE="$(stat -c%s ${DISK_RAW})"
T_SIZE="$((TARGET_SIZE * 1073741824))"

IMAGE_META="${IMAGE_NAME}.meta"
IMAGE_OVF="${IMAGE_NAME}.ovf"
IMAGE_OVA="${IMAGE_NAME}.ova"

echo "Creating meta specfile ... ${IMAGE_META}"
cat << EOF > "${IMAGE_META}"
os-type = ${OS_TYPE}
architecture = ppc64le
vol1-file = ${DISK_RAW}
vol1-type = boot
EOF

echo "Creating ovf specfile ... ${IMAGE_OVF}"
cat << EOF > "${IMAGE_OVF}"
<?xml version="1.0" encoding="UTF-8"?>
<ovf:Envelope xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <ovf:References>
    <ovf:File href="${DISK_RAW}" id="file1" size="${IMAGE_SIZE}"/>
  </ovf:References>
  <ovf:DiskSection>
    <ovf:Info>Disk Section</ovf:Info>
    <ovf:Disk capacity="${T_SIZE}" capacityAllocationUnits="byte" diskId="disk1" fileRef="file1"/>
  </ovf:DiskSection>
  <ovf:VirtualSystemCollection>
    <ovf:VirtualSystem ovf:id="vs0">
      <ovf:Name>${IMAGE_NAME}</ovf:Name>
      <ovf:Info></ovf:Info>
      <ovf:ProductSection>
        <ovf:Info/>
        <ovf:Product/>
      </ovf:ProductSection>
      <ovf:OperatingSystemSection ovf:id="${OS_ID}">
        <ovf:Info/>
        <ovf:Description>${OS_DESCRIPTION}</ovf:Description>
        <ns0:architecture xmlns:ns0="ibmpvc">ppc64le</ns0:architecture>
      </ovf:OperatingSystemSection>
      <ovf:VirtualHardwareSection>
        <ovf:Info>Storage resources</ovf:Info>
        <ovf:Item>
          <rasd:Description></rasd:Description>
          <rasd:ElementName>${DISK_RAW}</rasd:ElementName>
          <rasd:HostResource>ovf:/disk/disk1</rasd:HostResource>
          <rasd:InstanceID>1</rasd:InstanceID>
          <rasd:ResourceType>17</rasd:ResourceType>
          <ns1:boot xmlns:ns1="ibmpvc">True</ns1:boot>
        </ovf:Item>
      </ovf:VirtualHardwareSection>
    </ovf:VirtualSystem>
    <ovf:Info/>
    <ovf:Name>${IMAGE_NAME}</ovf:Name>
  </ovf:VirtualSystemCollection>
</ovf:Envelope>
EOF

echo "Creating ova file ... ${IMAGE_OVA} with ${IMAGE_OVA} ${IMAGE_META} ${IMAGE_OVF}"
tar -cf "${IMAGE_OVA}" "${IMAGE_META}" "${IMAGE_OVF}" "${DISK_RAW}"
echo "Done!"

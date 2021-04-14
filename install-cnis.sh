#!/bin/sh

# Choose which default cni binaries should be copied
SKIP_CNI_BINARIES=${SKIP_CNI_BINARIES:-""}
SKIP_CNI_BINARIES=",$SKIP_CNI_BINARIES,"
UPDATE_CNI_BINARIES=${UPDATE_CNI_BINARIES:-"true"}

# Place the new binaries if the directory is writeable.
for dir in /host/opt/cni/bin
do
  if [ ! -w "$dir" ];
  then
    echo "$dir is non-writeable, skipping"
    continue
  fi
  for path in /opt/cni/bin/*;
  do
    filename="$(basename "$path")"
    tmp=",$filename,"
    if [ "${SKIP_CNI_BINARIES#*$tmp}" != "$SKIP_CNI_BINARIES" ];
    then
      echo "$filename is in SKIP_CNI_BINARIES, skipping"
      continue
    fi
    if [ "${UPDATE_CNI_BINARIES}" != "true" ] && [ -f $dir/"$filename" ];
    then
      echo "$dir/$filename is already here and UPDATE_CNI_BINARIES isn't true, skipping"
      continue
    fi
    cp "$path" $dir/ || exit_with_error "Failed to copy $path to $dir. This may be caused by selinux configuration on the host, or something else."
  done
done

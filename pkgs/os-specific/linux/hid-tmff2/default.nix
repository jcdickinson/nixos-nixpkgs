{ stdenv, lib, fetchFromGitHub, kernel, kernelModuleMakeFlags }:

stdenv.mkDerivation {
  pname = "hid-tmff2";
  # https://github.com/Kimplul/hid-tmff2/blob/ca168637fbfb085ebc9ade0c47fa0653dac5d25b/dkms/dkms-install.sh#L12
  version = "0.82";

  src = fetchFromGitHub {
    owner = "Kimplul";
    repo = "hid-tmff2";
    rev = "343c01bcddf5368ef5465c9848c37bbe6ffc950d";
    hash = "sha256-ojul5Er6z+cd5dj6J/yAUaGtX6g2Z2eBNCsnOKmqHck=";
    # For hid-tminit. Source: https://github.com/scarburato/hid-tminit
    fetchSubmodules = true;
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernelModuleMakeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installFlags = [
    "INSTALL_MOD_PATH=${placeholder "out"}"
  ];

  postPatch = "sed -i '/depmod -A/d' Makefile";

  meta = with lib; {
    description = "Linux kernel module for Thrustmaster T300RS, T248 and TX(experimental)";
    homepage = "https://github.com/Kimplul/hid-tmff2";
    license = licenses.gpl2Plus;
    maintainers = [ maintainers.rayslash ];
    platforms = platforms.linux;
  };
}

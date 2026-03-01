locals {
  instance = {
    arm = {
      shape            = "VM.Standard.A1.Flex"
      image_ocid       = "ocid1.image.oc1.ca-montreal-1.aaaaaaaa7f73hpjf2wa62jpmqyvrofoyjcudltupmftsjmri72xkgqghykla"
      user_data = {
        runcmd = ["apt-get remove --quiet --assume-yes --purge apparmor"]
      }
    }
  }
}
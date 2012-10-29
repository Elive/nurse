#!/usr/bin/awk -f

# There's no doc cowboy, read the source code !
# Parameters:
#   kernel_version    Version number of the kernel (same as: uname -r)
# Extra Parameters:
#   external_title    Use a different title
#   extra_args        Set extra arguments passed to the boot options

BEGIN {
   FS="\n"
   OFS="\n"
   RS=""
   ORS="\n\n"
}   

{
   if ($1 ~ /^title Elive/ && ! firstmatch && $1 !~ /Reparation/ )
   {
      original = $0
      title_on = $1
      gsub (/\/vmlinuz-[^ ]*/,"/vmlinuz-"kernel_version)
      gsub (/\/initrd.img-[^ ]*/,"/initrd.img-"kernel_version)
      gsub (/.*\(on/, " (on", title_on)

      if (remove_root_device == "yes")
         gsub (/root=[^ ]* /,"")

      if (remove_resume == "yes")
         gsub (/resume=[^ ]* /,"")

      if (title_on !~ "\\(on") title_on = ""

      split($0, words, " ")
      first = words[1]
      second = words[2];
      third = words[3];

      if ( external_title != "" )
         $1 = first " " external_title title_on
      else
         $1 = first " " second " " third " " kernel_version title_on

      if ( extra_args != "" )
         $3 = $3 " " extra_args

      print
      print original
      firstmatch = 1
   }
   else
      print
   fi
}



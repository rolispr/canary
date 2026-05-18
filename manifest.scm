(use-modules (gnu packages commencement)
             (gnu packages guile)
             (gnu packages guile-xyz)
             (gnu packages version-control))

(packages->manifest
 (list guile-next
       guile-fibers
       gcc-toolchain
       gnu-make
       git))

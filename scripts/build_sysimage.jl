using PackageCompiler

create_sysimage(
    [:JSON, :ArgParse];
    sysimage_path = "dyn_sysimage.so",
)

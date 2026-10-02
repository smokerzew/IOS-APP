#!/usr/bin/env python3
"""Regenerates Frameline.xcodeproj from the files on disk.

Run from the repository root after adding, removing or moving source files:

    python3 Tools/generate_xcodeproj.py

Identifiers are derived from file paths, so regenerating without changes
produces an identical project file.
"""

import hashlib
import os
import re

APP = "Frameline"
SOURCE_DIR = "Frameline"
CONFIG_DIR = "Config"
BUNDLE_ID = "com.example.frameline"
DEPLOYMENT_TARGET = "17.0"

FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".xcassets": "folder.assetcatalog",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcprivacy": "text.xml",
}
RESOURCE_EXTENSIONS = {".xcassets", ".xcprivacy"}


def uid(key):
    return hashlib.md5(key.encode()).hexdigest()[:24].upper()


def quote(value):
    return value if re.fullmatch(r"[A-Za-z0-9_./]+", value) else '"%s"' % value.replace('"', '\\"')


class Node:
    def __init__(self, name, path, is_group):
        self.name = name
        self.path = path
        self.is_group = is_group
        self.children = []
        self.id = uid(("group:" if is_group else "file:") + path)


def scan(directory):
    """Builds the group tree; bundles such as .xcassets are single files."""
    node = Node(os.path.basename(directory), directory, True)
    for entry in sorted(os.listdir(directory)):
        if entry.startswith("."):
            continue
        full = os.path.join(directory, entry)
        extension = os.path.splitext(entry)[1]
        if os.path.isdir(full) and extension not in FILE_TYPES:
            node.children.append(scan(full))
        elif extension in FILE_TYPES:
            node.children.append(Node(entry, full, False))
    # Folders first, then files, each alphabetical: the order Xcode shows.
    node.children.sort(key=lambda child: (not child.is_group, child.name.lower()))
    return node


def flatten(node):
    for child in node.children:
        if child.is_group:
            yield from flatten(child)
        else:
            yield child


def settings_block(settings, indent):
    lines = []
    for key in sorted(settings):
        value = settings[key]
        if isinstance(value, list):
            lines.append("%s%s = (" % (indent, key))
            lines.extend('%s\t%s,' % (indent, quote(item)) for item in value)
            lines.append("%s);" % indent)
        else:
            lines.append("%s%s = %s;" % (indent, key, quote(value)))
    return "\n".join(lines)


def main():
    source_root = scan(SOURCE_DIR)
    config_root = scan(CONFIG_DIR)
    files = list(flatten(source_root))
    sources = [f for f in files if f.name.endswith(".swift")]
    resources = [f for f in files if os.path.splitext(f.name)[1] in RESOURCE_EXTENSIONS]

    project_id = uid("project")
    target_id = uid("target")
    product_id = uid("product")
    products_group_id = uid("group:Products")
    main_group_id = uid("group:main")
    sources_phase_id = uid("phase:sources")
    frameworks_phase_id = uid("phase:frameworks")
    resources_phase_id = uid("phase:resources")
    project_configs_id = uid("configlist:project")
    target_configs_id = uid("configlist:target")
    config_ids = {key: uid("config:" + key) for key in
                  ("project:Debug", "project:Release", "target:Debug", "target:Release")}

    def build_file_id(node):
        return uid("build:" + node.path)

    out = []
    w = out.append
    w("// !$*UTF8*$!")
    w("{")
    w("\tarchiveVersion = 1;")
    w("\tclasses = {")
    w("\t};")
    w("\tobjectVersion = 56;")
    w("\tobjects = {")
    w("")

    w("/* Begin PBXBuildFile section */")
    for node in sorted(sources + resources, key=lambda n: build_file_id(n)):
        phase = "Sources" if node in sources else "Resources"
        w("\t\t%s /* %s in %s */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };"
          % (build_file_id(node), node.name, phase, node.id, node.name))
    w("/* End PBXBuildFile section */")
    w("")

    w("/* Begin PBXFileReference section */")
    w("\t\t%s /* %s.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; "
      "includeInIndex = 0; path = %s.app; sourceTree = BUILT_PRODUCTS_DIR; };" % (product_id, APP, APP))
    for node in sorted(files + list(flatten(config_root)), key=lambda n: n.id):
        file_type = FILE_TYPES[os.path.splitext(node.name)[1]]
        w("\t\t%s /* %s */ = {isa = PBXFileReference; lastKnownFileType = %s; path = %s; "
          'sourceTree = "<group>"; };' % (node.id, node.name, file_type, quote(node.name)))
    w("/* End PBXFileReference section */")
    w("")

    w("/* Begin PBXFrameworksBuildPhase section */")
    w("\t\t%s /* Frameworks */ = {" % frameworks_phase_id)
    w("\t\t\tisa = PBXFrameworksBuildPhase;")
    w("\t\t\tbuildActionMask = 2147483647;")
    w("\t\t\tfiles = (")
    w("\t\t\t);")
    w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    w("\t\t};")
    w("/* End PBXFrameworksBuildPhase section */")
    w("")

    w("/* Begin PBXGroup section */")

    def write_group(group_id, name, children, path=None):
        w("\t\t%s /* %s */ = {" % (group_id, name))
        w("\t\t\tisa = PBXGroup;")
        w("\t\t\tchildren = (")
        for child_id, child_name in children:
            w("\t\t\t\t%s /* %s */," % (child_id, child_name))
        w("\t\t\t);")
        if path is not None:
            w("\t\t\tpath = %s;" % quote(path))
        else:
            w("\t\t\tname = %s;" % quote(name))
        w('\t\t\tsourceTree = "<group>";')
        w("\t\t};")

    w("\t\t%s = {" % main_group_id)
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    w("\t\t\t\t%s /* %s */," % (source_root.id, source_root.name))
    w("\t\t\t\t%s /* %s */," % (config_root.id, config_root.name))
    w("\t\t\t\t%s /* Products */," % products_group_id)
    w("\t\t\t);")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")
    write_group(products_group_id, "Products", [(product_id, APP + ".app")])

    def walk(node):
        write_group(node.id, node.name, [(c.id, c.name) for c in node.children], path=node.name)
        for child in node.children:
            if child.is_group:
                walk(child)

    walk(source_root)
    walk(config_root)
    w("/* End PBXGroup section */")
    w("")

    w("/* Begin PBXNativeTarget section */")
    w("\t\t%s /* %s */ = {" % (target_id, APP))
    w("\t\t\tisa = PBXNativeTarget;")
    w('\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget "%s" */;'
      % (target_configs_id, APP))
    w("\t\t\tbuildPhases = (")
    w("\t\t\t\t%s /* Sources */," % sources_phase_id)
    w("\t\t\t\t%s /* Frameworks */," % frameworks_phase_id)
    w("\t\t\t\t%s /* Resources */," % resources_phase_id)
    w("\t\t\t);")
    w("\t\t\tbuildRules = (")
    w("\t\t\t);")
    w("\t\t\tdependencies = (")
    w("\t\t\t);")
    w("\t\t\tname = %s;" % APP)
    w("\t\t\tproductName = %s;" % APP)
    w("\t\t\tproductReference = %s /* %s.app */;" % (product_id, APP))
    w('\t\t\tproductType = "com.apple.product-type.application";')
    w("\t\t};")
    w("/* End PBXNativeTarget section */")
    w("")

    w("/* Begin PBXProject section */")
    w("\t\t%s /* Project object */ = {" % project_id)
    w("\t\t\tisa = PBXProject;")
    w("\t\t\tattributes = {")
    w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    w("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    w("\t\t\t\tLastUpgradeCheck = 1500;")
    w("\t\t\t\tTargetAttributes = {")
    w("\t\t\t\t\t%s = {" % target_id)
    w("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    w("\t\t\t\t\t};")
    w("\t\t\t\t};")
    w("\t\t\t};")
    w('\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXProject "%s" */;'
      % (project_configs_id, APP))
    w('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    w("\t\t\tdevelopmentRegion = en;")
    w("\t\t\thasScannedForEncodings = 0;")
    w("\t\t\tknownRegions = (")
    w("\t\t\t\ten,")
    w("\t\t\t\tBase,")
    w("\t\t\t);")
    w("\t\t\tmainGroup = %s;" % main_group_id)
    w("\t\t\tproductRefGroup = %s /* Products */;" % products_group_id)
    w('\t\t\tprojectDirPath = "";')
    w('\t\t\tprojectRoot = "";')
    w("\t\t\ttargets = (")
    w("\t\t\t\t%s /* %s */," % (target_id, APP))
    w("\t\t\t);")
    w("\t\t};")
    w("/* End PBXProject section */")
    w("")

    def write_phase(section, phase_id, name, nodes):
        w("/* Begin %s section */" % section)
        w("\t\t%s /* %s */ = {" % (phase_id, name))
        w("\t\t\tisa = %s;" % section)
        w("\t\t\tbuildActionMask = 2147483647;")
        w("\t\t\tfiles = (")
        for node in nodes:
            w("\t\t\t\t%s /* %s in %s */," % (build_file_id(node), node.name, name))
        w("\t\t\t);")
        w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        w("\t\t};")
        w("/* End %s section */" % section)
        w("")

    write_phase("PBXResourcesBuildPhase", resources_phase_id, "Resources", resources)
    write_phase("PBXSourcesBuildPhase", sources_phase_id, "Sources", sources)

    shared = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_C_LANGUAGE_STANDARD": "gnu17",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES",
        "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
        "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION": "YES",
        "GCC_WARN_UNUSED_VARIABLE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
        "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
        "MTL_FAST_MATH": "YES",
        "SDKROOT": "iphoneos",
    }
    project_debug = dict(shared, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    })
    project_release = dict(shared, **{
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "VALIDATE_PRODUCT": "YES",
    })
    target_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_ENTITLEMENTS": "%s/%s.entitlements" % (CONFIG_DIR, APP),
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "DEVELOPMENT_TEAM": "",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "%s/Info.plist" % CONFIG_DIR,
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }

    w("/* Begin XCBuildConfiguration section */")
    for key, name, settings in (
        ("project:Debug", "Debug", project_debug),
        ("project:Release", "Release", project_release),
        ("target:Debug", "Debug", target_settings),
        ("target:Release", "Release", target_settings),
    ):
        w("\t\t%s /* %s */ = {" % (config_ids[key], name))
        w("\t\t\tisa = XCBuildConfiguration;")
        w("\t\t\tbuildSettings = {")
        w(settings_block(settings, "\t\t\t\t"))
        w("\t\t\t};")
        w("\t\t\tname = %s;" % name)
        w("\t\t};")
    w("/* End XCBuildConfiguration section */")
    w("")

    w("/* Begin XCConfigurationList section */")
    for list_id, label, scope in (
        (project_configs_id, 'PBXProject "%s"' % APP, "project"),
        (target_configs_id, 'PBXNativeTarget "%s"' % APP, "target"),
    ):
        w("\t\t%s /* Build configuration list for %s */ = {" % (list_id, label))
        w("\t\t\tisa = XCConfigurationList;")
        w("\t\t\tbuildConfigurations = (")
        w("\t\t\t\t%s /* Debug */," % config_ids[scope + ":Debug"])
        w("\t\t\t\t%s /* Release */," % config_ids[scope + ":Release"])
        w("\t\t\t);")
        w("\t\t\tdefaultConfigurationIsVisible = 0;")
        w("\t\t\tdefaultConfigurationName = Release;")
        w("\t\t};")
    w("/* End XCConfigurationList section */")
    w("\t};")
    w("\trootObject = %s /* Project object */;" % project_id)
    w("}")

    project_dir = APP + ".xcodeproj"
    os.makedirs(project_dir, exist_ok=True)
    with open(os.path.join(project_dir, "project.pbxproj"), "w") as handle:
        handle.write("\n".join(out) + "\n")
    print("Wrote %s/project.pbxproj: %d sources, %d resources"
          % (project_dir, len(sources), len(resources)))


if __name__ == "__main__":
    main()

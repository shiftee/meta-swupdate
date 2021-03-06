def swupdate_is_hash_needed(s, filename):
    with open(os.path.join(s, "sw-description"), 'r') as f:
        for line in f:
            if line.find("@%s" % (filename)) != -1:
                return True
    return False

def swupdate_get_sha256(s, filename):
    import hashlib

    m = hashlib.sha256()

    with open(os.path.join(s, filename), 'rb') as f:
        while True:
            data = f.read(1024)
            if not data:
                break
            m.update(data)
    return m.hexdigest()

def swupdate_write_sha256(s, filename, hash):
    write_lines = []

    with open(os.path.join(s, "sw-description"), 'r') as f:
        for line in f:
            write_lines.append(line.replace("@%s" % (filename), hash))

    with open(os.path.join(s, "sw-description"), 'w+') as f:
        for line in write_lines:
            f.write(line)

def prepare_sw_description(d, s, list_for_cpio):

    for file in list_for_cpio:
        if file != 'sw-description' and swupdate_is_hash_needed(s, file):
            hash = swupdate_get_sha256(s, file)
            swupdate_write_sha256(s, file, hash)

    signing = d.getVar('SWUPDATE_SIGNING', True)
    if signing == "1":
        bb.warn('SWUPDATE_SIGNING = "1" is deprecated, falling back to "RSA". It is advised to set it to "RSA" if using RSA signing.')
        signing = "RSA"
    if signing:
        if signing == "CUSTOM":
            sign_tool = d.getVar('SWUPDATE_SIGN_TOOL', True)
            if sign_tool:
                ret = os.system(sign_tool)
                if ret != 0:
                    bb.fatal("Failed to sign with %s" % (sign_tool))
            else:
                bb.fatal("Custom SWUPDATE_SIGN_TOOL is not given")
        elif signing == "RSA":
            privkey = d.getVar('SWUPDATE_PRIVATE_KEY', True)
            if not privkey:
                bb.fatal("SWUPDATE_PRIVATE_KEY isn't set")
            if not os.path.exists(privkey):
                bb.fatal("SWUPDATE_PRIVATE_KEY %s doesn't exist" % (privkey))
            passout = d.getVar('SWUPDATE_PASSWORD_FILE', True)
            if passout:
                passout = "-passin file:'%s' " % (passout)
            else:
                passout = ""
            signcmd = "openssl dgst -sha256 -sign '%s' %s -out '%s' '%s'" % (
                privkey,
                passout,
                os.path.join(s, 'sw-description.sig'),
                os.path.join(s, 'sw-description'))
            if os.system(signcmd) != 0:
                bb.fatal("Failed to sign sw-description with %s" % (privkey))
        elif signing == "CMS":
            cms_cert = d.getVar('SWUPDATE_CMS_CERT', True)
            if not cms_cert:
                bb.fatal("SWUPDATE_CMS_CERT is not set")
            if not os.path.exists(cms_cert):
                bb.fatal("SWUPDATE_CMS_CERT %s doesn't exist" % (cms_cert))
            cms_key = d.getVar('SWUPDATE_CMS_KEY', True)
            if not cms_key:
                bb.fatal("SWUPDATE_CMS_KEY isn't set")
            if not os.path.exists(cms_key):
                bb.fatal("SWUPDATE_CMS_KEY %s doesn't exist" % (cms_key))
            signcmd = "openssl cms -sign -in '%s' -out '%s' -signer '%s' -inkey '%s' -outform DER -nosmimecap -binary" % (
                os.path.join(s, 'sw-description'),
                os.path.join(s, 'sw-description.sig'),
                cms_cert,
                cms_key)
            if os.system(signcmd) != 0:
                bb.fatal("Failed to sign sw-description with %s" % (privkey))
        else:
            bb.fatal("Unrecognized SWUPDATE_SIGNING mechanism.");

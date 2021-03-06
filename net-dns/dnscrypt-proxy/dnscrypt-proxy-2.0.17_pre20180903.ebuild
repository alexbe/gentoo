# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6

EGIT_COMMIT="da5ee45b8ceb9233f4bc21b2a5f1eb7c875947cc"
EGO_PN="github.com/jedisct1/${PN}"
MY_P="${PN}-${EGIT_COMMIT}"

inherit fcaps golang-build systemd user

DESCRIPTION="A flexible DNS proxy, with support for encrypted DNS protocols"
HOMEPAGE="https://github.com/jedisct1/dnscrypt-proxy"
SRC_URI="https://${EGO_PN}/archive/${EGIT_COMMIT}.tar.gz -> ${MY_P}.tar.gz"

LICENSE="ISC"
SLOT="0"
KEYWORDS="~amd64 ~arm ~x86"
IUSE="pie test"

FILECAPS=( cap_net_bind_service+ep usr/bin/dnscrypt-proxy )
PATCHES=( "${FILESDIR}"/config-full-paths-r10.patch )

S="${WORKDIR}/${MY_P}"

pkg_setup() {
	enewgroup dnscrypt-proxy
	enewuser dnscrypt-proxy -1 -1 /var/empty dnscrypt-proxy
}

src_prepare() {
	default
	# Create directory structure suitable for building
	mkdir -p "src/${EGO_PN%/*}" || die
	mv "${PN}" "src/${EGO_PN}" || die
	mv "vendor" "src/" || die
}

src_configure() {
	EGO_BUILD_FLAGS="-buildmode=$(usex pie pie default)"
}

src_compile() {
	ego_pn_check
	GOPATH="${WORKDIR}/${MY_P}:$(get_golibdir_gopath)" \
	go build -v -work -x ${EGO_BUILD_FLAGS} "${EGO_PN}" || die
}

src_test() {
	ego_pn_check
	GOPATH="${WORKDIR}/${MY_P}:$(get_golibdir_gopath)" \
	go test -v -work -x "${EGO_PN}"
}

src_install() {
	dobin dnscrypt-proxy

	insinto /etc/dnscrypt-proxy
	newins "src/${EGO_PN}"/example-dnscrypt-proxy.toml dnscrypt-proxy.toml
	doins "src/${EGO_PN}"/example-{blacklist.txt,whitelist.txt}
	doins "src/${EGO_PN}"/example-{cloaking-rules.txt,forwarding-rules.txt}

	insinto /usr/share/dnscrypt-proxy
	doins -r "utils/generate-domains-blacklists/."

	newinitd "${FILESDIR}"/dnscrypt-proxy.initd dnscrypt-proxy
	newconfd "${FILESDIR}"/dnscrypt-proxy.confd dnscrypt-proxy
	systemd_newunit "${FILESDIR}"/dnscrypt-proxy.service dnscrypt-proxy.service
	systemd_newunit "${FILESDIR}"/dnscrypt-proxy.socket dnscrypt-proxy.socket

	einstalldocs
}

pkg_postinst() {
	fcaps_pkg_postinst

	if ! use filecaps; then
		ewarn "'filecaps' USE flag is disabled"
		ewarn "${PN} will fail to listen on port 53"
		ewarn "please do one the following:"
		ewarn "1) re-enable 'filecaps'"
		ewarn "2) change port to > 1024"
		ewarn "3) configure to run ${PN} as root (not recommended)"
		ewarn
	fi

	local v
	for v in ${REPLACING_VERSIONS}; do
		if [[ ${v} == 1.* ]] ; then
			elog "Version 2 is a complete rewrite of ${PN}"
			elog "please clean up old config/log files"
			elog
		fi
		if [[ ${v} == 2.* ]] ; then
			elog "As of version 2.0.12 of ${PN} runs as an 'dnscrypt-proxy' user/group"
			elog "you can remove obsolete 'dnscrypt' accounts from the system"
			elog
		fi
	done

	if systemd_is_booted || has_version sys-apps/systemd; then
		elog "Using systemd socket activation may cause issues with speed"
		elog "latency and reliability of ${PN} and is discouraged by upstream"
		elog "Existing installations advised to disable 'dnscrypt-proxy.socket'"
		elog "It is disabled by default for new installations"
		elog "check "$(systemd_get_systemunitdir)/${PN}.service" for details"
		elog

	fi

	elog "After starting the service you will need to update your"
	elog "/etc/resolv.conf and replace your current set of resolvers"
	elog "with:"
	elog
	elog "nameserver 127.0.0.1"
	elog
	elog "Also see https://github.com/jedisct1/${PN}/wiki"
}

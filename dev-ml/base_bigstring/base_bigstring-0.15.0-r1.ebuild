# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit dune

DESCRIPTION="String type based on Bigarray, for use in I/O and C-bindings"
HOMEPAGE="https://github.com/janestreet/base_bigstring"
SRC_URI="https://github.com/janestreet/${PN}/archive/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0/$(ver_cut 1-2)"
KEYWORDS="~amd64 ~riscv ~x86"
IUSE="+ocamlopt"

DEPEND="
	dev-ml/base:=
	dev-ml/int_repr:${SLOT}
"
RDEPEND="${DEPEND}"

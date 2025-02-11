# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake edo flag-o-matic

DESCRIPTION="Radeon Open Compute OpenCL Compatible Runtime"
HOMEPAGE="https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime"

if [[ ${PV} == *9999 ]] ; then
	EGIT_REPO_URI="https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime"
	EGIT_CLR_REPO_URI="https://github.com/ROCm-Developer-Tools/ROCclr"
	inherit git-r3
	S="${WORKDIR}/${P}"
else
	SRC_URI="https://github.com/ROCm-Developer-Tools/ROCclr/archive/rocm-${PV}.tar.gz -> rocclr-${PV}.tar.gz
	https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/archive/rocm-${PV}.tar.gz -> rocm-opencl-runtime-${PV}.tar.gz"
	S="${WORKDIR}/ROCm-OpenCL-Runtime-rocm-${PV}"
fi

LICENSE="Apache-2.0 MIT"
SLOT="0/$(ver_cut 1-2)"
IUSE="debug test"
RESTRICT="!test? ( test )"

RDEPEND=">=dev-libs/rocr-runtime-5.3
	>=dev-libs/rocm-comgr-5.3
	>=dev-libs/rocm-device-libs-5.3
	>=virtual/opencl-3
	media-libs/mesa"
DEPEND="${RDEPEND}"
BDEPEND=">=dev-util/rocm-cmake-5.3
	media-libs/glew
	test? ( >=x11-apps/mesa-progs-8.5.0[X] )
	"

CLR_S="${WORKDIR}/ROCclr-rocm-${PV}"
PATCHES=( "${FILESDIR}/${PN}-5.3.3-gcc13.patch" )

src_unpack () {
if [[ ${PV} == "9999" ]]; then
		git-r3_fetch
		git-r3_checkout
		git-r3_fetch "${EGIT_CLR_REPO_URI}"
		git-r3_checkout "${EGIT_CLR_REPO_URI}" "${CLR_S}"
	else
		default
	fi
}
src_prepare() {
	cmake_src_prepare

	pushd ${CLR_S} || die
	# Bug #753377
	# patch re-enables accidentally disabled gfx800 family
	eapply "${FILESDIR}/${PN}-5.0.2-enable-gfx800.patch"
	eapply "${FILESDIR}/rocclr-5.3.3-gcc13.patch"
	popd || die
}

src_configure() {
	# Reported upstream: https://github.com/RadeonOpenCompute/ROCm-OpenCL-Runtime/issues/120
	append-cflags -fcommon

	local mycmakeargs=(
		-Wno-dev
		-DROCCLR_PATH="${CLR_S}"
		-DAMD_OPENCL_PATH="${S}"
		-DROCM_PATH="${EPREFIX}/usr"
		-DBUILD_TESTS=$(usex test ON OFF)
		-DEMU_ENV=ON
		-DBUILD_ICD=OFF
		-DFILE_REORG_BACKWARD_COMPATIBILITY=OFF
	)
	cmake_src_configure
}

src_install() {
	insinto /etc/OpenCL/vendors
	doins config/amdocl64.icd

	cd "${BUILD_DIR}" || die
	insinto /usr/lib64
	doins amdocl/libamdocl64.so
	doins tools/cltrace/libcltrace.so
}

# Copied from rocm.eclass. This ebuild does not need amdgpu_targets
# USE_EXPANDS, so it should not inherit rocm.eclass; it only uses the
# check_amdgpu function in src_test. Rename it to check-amdgpu to avoid
# pkgcheck warning.
check-amdgpu() {
	for device in /dev/kfd /dev/dri/render*; do
		addwrite ${device}
		if [[ ! -r ${device} || ! -w ${device} ]]; then
			eerror "Cannot read or write ${device}!"
			eerror "Make sure it is present and check the permission."
			ewarn "By default render group have access to it. Check if portage user is in render group."
			die "${device} inaccessible"
		fi
	done
}

src_test() {
	check-amdgpu
	cd "${BUILD_DIR}"/tests/ocltst || die
	export OCL_ICD_FILENAMES="${BUILD_DIR}"/amdocl/libamdocl64.so
	local instruction1="Please start an X server using amdgpu driver (not Xvfb!),"
	local instruction2="and export OCLGL_DISPLAY=\${DISPLAY} OCLGL_XAUTHORITY=\${XAUTHORITY} before reruning the test."
	if [[ -n ${OCLGL_DISPLAY+x} ]]; then
		export DISPLAY=${OCLGL_DISPLAY}
		export XAUTHORITY=${OCLGL_XAUTHORITY}
		ebegin "Running oclgl test under DISPLAY ${OCLGL_DISPLAY}"
		if ! glxinfo | grep "OpenGL vendor string: AMD"; then
			ewarn "${instruction1}"
			ewarn "${instruction2}"
			die "This display does not have AMD OpenGL vendor!"
		fi
		./ocltst -m $(realpath liboclgl.so) -A ogl.exclude
		eend $? || die "oclgl test failed"
	else
		ewarn "${instruction1}"
		ewarn "${instruction2}"
		die "\${OCLGL_DISPLAY} not set."
	fi
	edob ./ocltst -m $(realpath liboclruntime.so) -A oclruntime.exclude
	edob ./ocltst -m $(realpath liboclperf.so) -A oclperf.exclude
}

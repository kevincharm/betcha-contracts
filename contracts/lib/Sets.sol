// SPDX-License-Identifier: MIT
pragma solidity >=0.8 <0.9;

library Sets {
    struct Set {
        mapping(address => address) ll;
        uint256 size;
    }

    address public constant OUROBOROS = address(0x1);

    function init(Set storage set) internal {
        require(set.ll[OUROBOROS] == address(0));
        set.ll[OUROBOROS] = OUROBOROS;
    }

    function tail(Set storage set) internal view returns (address) {
        address t = set.ll[OUROBOROS];
        require(
            t != address(0) && t != OUROBOROS,
            "Uninitialised or empty set"
        );
        return t;
    }

    function prev(
        Set storage set,
        address element
    ) internal view returns (address) {
        require(element != address(0), "Element must be nonzero");
        return set.ll[element];
    }

    function add(Set storage set, address element) internal {
        require(
            element != address(0) &&
                element != OUROBOROS &&
                set.ll[element] == address(0)
        );
        set.ll[element] = set.ll[OUROBOROS];
        set.ll[OUROBOROS] = element;
        ++set.size;
    }

    function del(
        Set storage set,
        address prevElement,
        address element
    ) internal {
        require(
            element == set.ll[prevElement],
            "prevElement is not linked to element"
        );
        require(
            element != address(0) && element != OUROBOROS,
            "Invalid element"
        );
        set.ll[prevElement] = set.ll[element];
        set.ll[element] = address(0);
        --set.size;
    }

    function has(
        Set storage set,
        address element
    ) internal view returns (bool) {
        return set.ll[element] != address(0);
    }

    function toArray(Set storage set) internal view returns (address[] memory) {
        if (set.size == 0) {
            return new address[](0);
        }

        address[] memory array = new address[](set.size);
        address element = set.ll[OUROBOROS];
        for (uint256 i; i < array.length; ++i) {
            array[i] = element;
            element = set.ll[element];
        }
        return array;
    }
}

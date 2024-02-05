use starknet::ContractAddress;

#[starknet::interface]
trait IOwnable<TContractState> {
    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
}

#[starknet::component]
mod OwnableComponent {
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    #[embeddable_as(Ownable)]
    impl OwnableImpl<TContractState, +HasComponent<TContractState>> of super::IOwnable<ComponentState<TContractState>> {
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner.read()
        }

        fn transfer_ownership(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            if new_owner.is_zero() {
                panic(array!['New owner is the zero address']);
            }
            self.assert_only_owner();
            let previous_owner = self.owner.read();
            self._transfer_ownership(new_owner);
            self.emit(OwnershipTransferred {previous_owner, new_owner});
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            self._transfer_ownership(Zeroable::zero());
        }
    }

    #[generate_trait]
    impl InternalImpl<TContractState, +HasComponent<TContractState>> of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let caller_address = get_caller_address();
            if caller_address.is_zero() {
                panic(array!['Caller is the zero address']);
            }
            if caller_address != self.owner.read() {
                panic(array!['Caller is not the owner'])
            }
        }

        fn _transfer_ownership(ref self: ComponentState<TContractState>, new_owner: ContractAddress) {
            self.owner.write(new_owner);
        }
    }
}
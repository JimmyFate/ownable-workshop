use starknet::ContractAddress;

#[starknet::interface]
trait ICounter<TContractState> {
    fn get_counter(self: @TContractState) -> u32;
    fn increase_counter(ref self: TContractState);
}


#[starknet::contract]
mod Counter {
    use starknet::{ContractAddress, get_caller_address, Zeroable};
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: IKillSwitchDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        OwnableEvent: OwnableComponent::Event
    }

    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        counter: u32,
    }

    #[constructor]
    fn constructor(ref self: ContractState, counter: u32, contract_address: ContractAddress, initial_owner: ContractAddress) {
        self.ownable.initializer(initial_owner);
        self.counter.write(counter);
        self.kill_switch.write(IKillSwitchDispatcher { contract_address });
    }

    #[abi(embed_v0)]
    impl ICounterImpl of super::ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();

            if self.kill_switch.read().is_active() {
                self.counter.write(self.counter.read() + 1);
                self.emit(CounterIncreased {counter: self.counter.read()});
            }
        }
    }
}

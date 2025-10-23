import { 
    AbiCoder,
    Addressable,
    Contract, 
    ContractRunner,
    Interface, 
    InterfaceAbi, 
    JsonRpcApiProvider,
    JsonRpcSigner,
} from "ethers"

export abstract class ContractWrapper {

    constructor (signer: JsonRpcSigner, network: string, abi: Interface | InterfaceAbi, target: string | Addressable) {
        this._address = target
        this._contract = new Contract(target, abi, signer as ContractRunner)
        this.abi = abi
        this.network = network
        this.provider = signer.provider
        this.signer = signer
    }

    protected _address: string | Addressable;
    protected _contract: Contract;

    public attach(target: string | Addressable): any {
        this._contract = new Contract(target, this.abi, this.signer)
        this._address = target
        return this
    }

    /**
     * The contract's ABI.
     */
    public readonly abi: Interface | InterfaceAbi

    /**
     * The address of the underlying Wit/Oracle Framework artifact.
     */
    public get address(): string | Addressable{
        return this._address
    }

    /**
     * The underlying Ethers' contract wrapper.
     */
    public get contract(): Contract {
        return this._contract
    }
    
    /**
     * The EVM network currently connected to.
     */
    public readonly network: string;

    /**
     * The ETH/RPC provider used of contract interactions.
     */
    public readonly provider: JsonRpcApiProvider;

    /**
     * The EVM address that will sign contract interaction transactions, when required.
     */
    public readonly signer: JsonRpcSigner;

    /**
     * Name of the underlying logic implementation contract. 
     * @returns Contract name.
     */
    public async getEvmImplClass(): Promise<string> {
        return this.contract
            .getFunction("class()")
            .staticCall()
    }

    /**
     * Get specs identifier of the underlying logic implementation contract.
     * @returns 4-byte hex string. 
     */
    public async getEvmImplSpecs(): Promise<string> {
        return this.contract
            .getFunction("specs()")
            .staticCall()
    }

    /**
     * Version tag of the underlying logic implementation contract. 
     * @returns Version tag. 
     */
    public async getEvmImplVersion(): Promise<string> {
        let version
        try {
            version = await this.provider
                .call({
                    to: this.address,
                    data: "0x54fd4d50", // funcSig for 'version()'
                })
                .then(result => AbiCoder.defaultAbiCoder().decode(["string"], result))
                .then(result => result.toString());
        } catch (_err) {
            return "(immutable)"
        }
        return version
    }
}
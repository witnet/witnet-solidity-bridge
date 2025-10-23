import { utils, Witnet } from "@witnet/sdk"
import { default as axios } from "axios"
import { default as jsonBig } from "json-bigint"
// const jsonBig = require('json-bigint')

import { DataPushReport } from "./types.js"

const stringify = (query: any) => Object.entries(query).map(([key, value]) => `&${key}=${value}`).join("").slice(1)

interface IKermitClient {
    getDataPushReport(witDrTxHash: Witnet.Hash, evmNetwork?: number | string): Promise<DataPushReport>;
    // searchDataRequests(hash: Hash, {}): Promise<any>;
}


export class KermitError extends Error {
    readonly error?: any;
    readonly path: string;
    readonly query?: any;
    constructor(path: string, query?: any, error?: any) {
        super(`${path}${stringify(query)}: ${JSON.stringify(error)}`)
        delete error?.stack
        this.error = error
        this.path = path
        this.query = query
    }
}

export class KermitClient implements IKermitClient {

    static async fromEnv(url?: string): Promise<KermitClient> {
        return new KermitClient(url || process.env.WITNET_KERMIT_PROVIDER_URL || "https://kermit.witnet.io")
    }

    public readonly url: string
    
    constructor(url: string) {
        const [schema, ] = utils.parseURL(url)
        if (!schema.startsWith("http://") && !schema.startsWith("https://")) {
            throw Error(`KermitClient: unsupported URL schema ${schema}`)
        }
        this.url = url
        if (!this.url.endsWith("/")) {
            this.url += "/"
        }
        if (!this.url.endsWith("api/")) {
            this.url += "api/"
        }
    }

    protected async callApiGetMethod<T>(path: string, query?: any): Promise<Error | any> {
        const url = `${this.url}${path}${query ? `?${stringify(query)}` : ""}`
        return axios
            .get(
                url,
                {
                    transformResponse: function(response) { return jsonBig().parse(response) },
                },

            ).then((response: any) => {
                if (response?.error || response?.data?.error) {
                    throw new KermitError(path, query, response?.error || response?.data?.error);
                } else if (response?.statusCode && response.statusCode !== 200) {
                    throw new KermitError(path, query, `server status code: HTTP/${response.statusCode}`)
                } else {
                    return response?.data as T;
                }
            }).catch(error => {
                throw new KermitError(path, query, error)
            })
    }

    public async getDataPushReport(witDrTxHash: Witnet.Hash, evmNetwork?: number | string): Promise<DataPushReport> {
        return this.callApiGetMethod<DataPushReport>(
            "get_data_push_report",
            {
                witDrTxHash,
                evmNetwork
            }
        )
    }
}

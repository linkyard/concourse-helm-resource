export declare function parseHelmStatus(status: string): Resource[];
export interface Resource {
    name: string;
    /** Kubernetes API type of this resource (eg v1/Service). */
    type: string;
    /** true if the resource is ready - returns true for things that don't have a state such as Secrets */
    isReady: boolean;
    desired?: number;
    current?: number;
    upToDate?: number;
    available?: number;
    successful?: number;
    volume?: string;
}
